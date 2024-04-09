# encoding: utf-8
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This work contains copyrighted material, see NOTICE for
# additional copyright aknowledgements.

require 'logstash-output-fabric_jars'
require 'logstash/outputs/base'
require 'logstash/namespace'
require 'logstash/errors'
require 'logstash/outputs/eventstream/eventStreamIngestor'
require 'logstash/outputs/kusto/ingestor'
require 'logstash/outputs/kusto/interval'

java_import com.azure.messaging.eventhubs.EventData
java_import com.azure.core.amqp.AmqpRetryMode
java_import com.azure.core.amqp.AmqpRetryOptions
java_import com.azure.messaging.eventhubs.EventData
java_import com.azure.messaging.eventhubs.EventDataBatch
java_import com.azure.messaging.eventhubs.EventHubClientBuilder
java_import com.azure.messaging.eventhubs.EventHubProducerClient
java_import com.microsoft.azure.kusto.data.auth.ConnectionStringBuilder



java_import java.time.Duration
java_import java.io.IOException
java_import java.nio.ByteBuffer
java_import java.nio.charset.Charset
java_import java.lang.IllegalArgumentException

# Output plugin to send events to an MS Fabric platform.
class LogStash::Outputs::Fabric < LogStash::Outputs::Base
  concurrency :shared
  attr_reader :failure_path  
  FIELD_REF = /%\{[^}]+\}/
  config_name "fabric"
  # Azure Service Namespace or Endpoint (Can be a KQLDB endpoint or an EventStream point)
  config :connection_string, :validate => :string, :required => false, :default => ""
  # Number of times to retry a failed message send to EventStream
  # Defaults to 3
  config :connection_retry_count, :validate => :number, :required => false, :default => 3
  default :codec, 'json_lines'


  # The Kusto endpoint for ingestion related communication. You can see it on the Azure Portal.
  config :ingest_url, validate: :string, required: false
  # The following are the credentails used to connect to the Kusto service
  # application id 
  config :app_id, validate: :string, required: false
  # application key (secret)
  config :app_key, validate: :password, required: false
  # aad tenant id
  config :app_tenant, validate: :string, default: nil
  # The Kusto config is copied from the Logstash output plugin for Kusto
  # This seems a little elaborate, but can be cleaned up later
  config :path, validate: :string, required: false
  config :flush_interval, validate: :number, default: 2
  config :filename_failure, validate: :string, default: '_filepath_failures'
  config :create_if_deleted, validate: :boolean, default: true
  config :dir_mode, validate: :number, default: -1
  config :file_mode, validate: :number, default: -1
  config :stale_cleanup_interval, validate: :number, default: 10
  config :stale_cleanup_type, validate: %w[events interval], default: 'events'
  config :recovery, validate: :boolean, default: true
  # managed identity id
  config :managed_identity, validate: :string, default: nil
  # Database name
  config :database, validate: :string, required: false
  # Target table name
  config :table, validate: :string, required: false
  # Mapping name - Used by Kusto to map each attribute from incoming event JSON strings to the appropriate column in the table.
  # Note that this must be in JSON format, as this is the interface between Logstash and Kusto
  # Make this optional as name resolution in the JSON mapping can be done based on attribute names in the incoming event JSON strings
  config :json_mapping, validate: :string, default: nil
  # Determines if local files used for temporary storage will be deleted
  # after upload is successful
  config :delete_temp_files, validate: :boolean, default: true
  # TODO: will be used to route events to many tables according to event properties
  config :dynamic_event_routing, validate: :boolean, default: false
  # Specify how many files can be uploaded concurrently
  config :upload_concurrent_count, validate: :number, default: 3
  # Specify how many files can be kept in the upload queue before the main process
  # starts processing them in the main thread (not healthy)
  config :upload_queue_size, validate: :number, default: 30
  # Host of the proxy , is an optional field. Can connect directly
  config :proxy_host, validate: :string, required: false
  # Port where the proxy runs , defaults to 80. Usually a value like 3128
  config :proxy_port, validate: :number, required: false , default: 80
  # Check Proxy URL can be over http or https. Dowe need it this way or ignore this & remove this
  config :proxy_protocol, validate: :string, required: false , default: 'http'

  public
  def register
    @io_mutex = Mutex.new
    @flush_interval = @flush_interval.to_i    
    @files={}
    if @connection_string.start_with?("Endpoint=sb")
      # Build Event Hubs client connection string
      # The case for EventStreams is quite straightforward. Just target the endpoint and use the EventBatch abstraction to send data
      @es_client = LogStash::Outputs::FabricInternal::FabricEventStreamClient.new(@connection_string, @connection_retry_count, @logger)
      @codec.on_event(&method(:send_record))
    else
      # This is a KQLDB endpoint
      @last_stale_cleanup_cycle = Time.now
      @logger.info("Initializing Kusto client as the connection string is not a EventStream endpoint.")
      require 'fileutils' # For mkdir_p
      final_mapping = json_mapping
      @path = if dynamic_event_routing
                File.expand_path("#{path}.%{[@metadata][database]}.%{[@metadata][table]}.%{[@metadata][final_mapping]}")
              else
                File.expand_path("#{path}.#{database}.#{table}")
              end
      validate_path
        @file_root = if path_with_field_ref?
                     extract_file_root
                   else
                     File.dirname(path)
                   end
      @failure_path = File.join(@file_root, @filename_failure)
      executor = Concurrent::ThreadPoolExecutor.new(min_threads: 1,
                                                    max_threads: upload_concurrent_count,
                                                    max_queue: upload_queue_size,
                                                    fallback_policy: :caller_runs)
      @ingestor = LogStash::Outputs::Kusto::Ingestor.new(ingest_url, app_id, app_key, app_tenant, managed_identity, database, table, final_mapping, delete_temp_files, proxy_host, proxy_port,proxy_protocol, @logger, executor)
      # send existing files
      recover_past_files if recovery
      if @flush_interval > 0
        @flusher = LogStash::Outputs::Kusto::Interval.start(@flush_interval, -> { flush_pending_files })
      end
      if (@stale_cleanup_type == 'interval') && (@stale_cleanup_interval > 0)
        @cleaner = LogStash::Outputs::Kusto::Interval.start(stale_cleanup_interval, -> { close_stale_files })
      end
    end 
  end # def register

  public
  def close
    @es_client.close() unless @es_client.nil?
    @flusher.stop unless @flusher.nil?
    @cleaner.stop unless @cleaner.nil?
    if not(@io_mutex.nil?)
      @io_mutex.synchronize do
        @logger.debug('Close: closing files')

        @files.each do |path, fd|
          begin
            fd.close
            @logger.debug("Closed file #{path}", fd: fd)

            kusto_send_file(path)
          rescue Exception => e
            @logger.error('Exception while flushing and closing files.', exception: e)
          end #end begin
        end # end nested do
      end # end do
    end  
    @ingestor.stop unless @ingestor.nil?
  end # def close
  
  public
  def receive(event)
    begin
      @codec.encode(event)
    rescue => e
      @logger.warn("Error encoding event", :exception => e, :event => event)
    end
  end # def receive

  private
  def send_record(event, payload)
    @es_client.ingest(event, payload)
  end # def send_record


  private
  def validate_path
    if (root_directory =~ FIELD_REF) != nil
      @logger.error('The starting part of the path should not be dynamic.', path: @path)
      raise LogStash::ConfigurationError.new('The starting part of the path should not be dynamic.')
    end

    if !path_with_field_ref?
      @logger.error('Path should include some time related fields to allow for file rotation.', path: @path)
      raise LogStash::ConfigurationError.new('Path should include some time related fields to allow for file rotation.')
    end
  end

  private 
  def root_directory
    parts = @path.split(File::SEPARATOR).reject(&:empty?)
    if Gem.win_platform?
      # First part is the drive letter
      parts[1]
    else
      parts.first
    end
  end

  public
  def multi_receive_encoded(events_and_encoded)
    encoded_by_path = Hash.new { |h, k| h[k] = [] }
    events_and_encoded.each do |event, encoded|
      file_output_path = event_path(event)
      encoded_by_path[file_output_path] << encoded
    end

    @io_mutex.synchronize do
      encoded_by_path.each do |path, chunks|
        fd = open(path)
        # append to the file
        chunks.each { |chunk| fd.write(chunk) }
        fd.flush unless @flusher && @flusher.alive?
      end
      close_stale_files if @stale_cleanup_type == 'events'
    end
  end


  private
  def inside_file_root?(log_path)
    target_file = File.expand_path(log_path)
    return target_file.start_with?("#{@file_root}/")
  end

  private
  def event_path(event)
    file_output_path = generate_filepath(event)
    if path_with_field_ref? && !inside_file_root?(file_output_path)
      @logger.warn('The event tried to write outside the files root, writing the event to the failure file', event: event, filename: @failure_path)
      file_output_path = @failure_path
    elsif !@create_if_deleted && deleted?(file_output_path)
      file_output_path = @failure_path
    end
    @logger.debug('Writing event to tmp file.', filename: file_output_path)

    file_output_path
  end

  private
  def generate_filepath(event)
    event.sprintf(@path)
  end

  private
  def path_with_field_ref?
    path =~ FIELD_REF
  end

  private
  def extract_file_root
    parts = File.expand_path(path).split(File::SEPARATOR)
    parts.take_while { |part| part !~ FIELD_REF }.join(File::SEPARATOR)
  end

  # the back-bone of @flusher, our periodic-flushing interval.
  private
  def flush_pending_files
    @io_mutex.synchronize do
      @logger.debug('Starting flush cycle')
      @files.each do |path, fd|
        @logger.debug('Flushing file', path: path, fd: fd)
        fd.flush
      end
    end
  rescue Exception => e
    # squash exceptions caught while flushing after logging them
    @logger.error('Exception flushing files', exception: e.message, backtrace: e.backtrace)
  end

  # every 10 seconds or so (triggered by events, but if there are no events there's no point closing files anyway)
  private
  def close_stale_files
    now = Time.now
    if @last_stale_cleanup_cycle.nil?
      @last_stale_cleanup_cycle = Time.now
    end
    return unless now - @last_stale_cleanup_cycle >= @stale_cleanup_interval
    if @files.nil?
      @files = {}
    end
    @logger.debug('Starting stale files cleanup cycle', files: @files)
    inactive_files = @files.select { |path, fd| not fd.active }
    @logger.debug("#{inactive_files.count} stale files found", inactive_files: inactive_files)
    inactive_files.each do |path, fd|
      @logger.info("Closing file #{path}")
      fd.close
      @files.delete(path)
      kusto_send_file(path)
    end
    # mark all files as inactive, a call to write will mark them as active again
    @files.each { |path, fd| fd.active = false }
    @last_stale_cleanup_cycle = now
  end

  private
  def cached?(path)
    @files.include?(path) && !@files[path].nil?
  end

  private
  def deleted?(path)
    !File.exist?(path)
  end

  private
  def open(path)
    return @files[path] if !deleted?(path) && cached?(path)

    if deleted?(path)
      if @create_if_deleted
        @logger.debug('Required file does not exist, creating it.', path: path)
        @files.delete(path)
      else
        return @files[path] if cached?(path)
      end
    end
    @logger.info('Opening file', path: path)
    dir = File.dirname(path)
    if !Dir.exist?(dir)
      @logger.info('Creating directory', directory: dir)
      if @dir_mode != -1
        FileUtils.mkdir_p(dir, mode: @dir_mode)
      else
        FileUtils.mkdir_p(dir)
      end
    end

    # work around a bug opening fifos (bug JRUBY-6280)
    stat = begin
             File.stat(path)
           rescue
             nil
           end
    fd =  if stat && stat.ftype == 'fifo' && LogStash::Environment.jruby?
            java.io.FileWriter.new(java.io.File.new(path))
          elsif @file_mode != -1
            File.new(path, 'a+', @file_mode)
          else
            File.new(path, 'a+')
          end
          # fd = if @file_mode != -1
          #         File.new(path, 'a+', @file_mode)
          #       else
          #         File.new(path, 'a+')
          #       end
        #  end
    @files[path] = IOWriter.new(fd)
  end

  private
  def kusto_send_file(file_path)
    @ingestor.upload_async(file_path, delete_temp_files)
  end

  private
  def recover_past_files
    require 'find'

    # we need to find the last "regular" part in the path before any dynamic vars
    path_last_char = @path.length - 1

    pattern_start = @path.index('%') || path_last_char
    last_folder_before_pattern = @path.rindex('/', pattern_start) || path_last_char
    new_path = path[0..last_folder_before_pattern]
    
    begin
      return unless Dir.exist?(new_path)
      @logger.info("Going to recover old files in path #{@new_path}")
      
      old_files = Find.find(new_path).select { |p| /.*\.#{database}\.#{table}$/ =~ p }
      @logger.info("Found #{old_files.length} old file(s), sending them now...")

      old_files.each do |file|
        kusto_send_file(file)
      end
    rescue Errno::ENOENT => e
      @logger.warn('No such file or directory', exception: e.class, message: e.message, path: new_path, backtrace: e.backtrace)
    end
  end
end # class LogStash::Outputs::MSFabric

# wrapper class
class IOWriter
  def initialize(io)
    @io = io
  end

  def write(*args)
    @io.write(*args)
    @active = true
  end

  def flush
    @io.flush
  end

  def method_missing(method_name, *args, &block)
    if @io.respond_to?(method_name)
      @io.send(method_name, *args, &block)
    else
      super
    end
  end
  attr_accessor :active
end

