# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
######################################################
# This plugin sends messages to Fabric in batches.
######################################################
class LogStash::Outputs::Fabric < LogStash::Outputs::Base
  # Name of the config
  config_name 'fabric'

  # Stating that the output plugin will run in concurrent mode
  concurrency :shared

  # The connnection string for connecting to EventHub or KQL DB on Fabric
  config :connection_string, :validate => :string

  # Max number of seconds to wait between flushes. Default 5
  config :plugin_flush_interval, :validate => :number, :default => 5

  # Setting the default amount of messages sent
  # it this is set with amount_resizing=false --> each message will have max_items
  config :max_items, :validate => :number, :default => 2000

  # This will set the amount of time given for retransmitting messages once sending is failed
  config :retransmission_time, :validate => :number, :default => 10

  # Compress the message body before sending it to Fabric targets
  config :compress_data, :validate => :boolean, :default => false

  # If managed identity is used , "system" for system managed identity and client id for user managed client ids
  config :managed_identity_id, :validate => :string


  public
  def register
    @logstash_configuration= build_logstash_configuration()
    # Validate configuration correctness 
    @logstash_configuration.validate_configuration()
    @events_handler = LogStash::Outputs::MicrosoftFabricInternal::LogsSender::new(@logstash_configuration)
  end # def register

  def multi_receive(events)
    @events_handler.handle_events(events)
  end # def multi_receive

  def close
    @events_handler.close
  end

  #private 
  private


  def build_logstash_configuration()
    logstash_configuration= LogStash::Outputs::MicrosoftFabricInternal::FabricOutputConfiguration::new(@connection_string, @plugin_flush_interval, @max_items, @retransmission_time, @compress_data, @managed_identity_id, @logger)
    return logstash_configuration
  end # def build_logstash_configuration


end # class LogStash::Outputs::Fabric
