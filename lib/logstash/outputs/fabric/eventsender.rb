# encoding: utf-8

require "logstash/outputs/fabricconfiguration"
require "logstash/outputs/eventshandler"

module LogStash; module Outputs; class MicrosoftFabricInternal
class EventsSender < EventsHandler
    @thread_batch_map

    def initialize(fabricconfiguration)
      @thread_batch_map = Concurrent::Hash.new
      @fabricconfiguration = fabricconfiguration
      @logger = fabricconfiguration.logger
      super
    end

    def handle_events(events)
      t = Thread.current
      
      unless @thread_batch_map.include?(t)
        @thread_batch_map[t] = @fabricconfiguration.compress_data ? 
                                  LogStashCompressedStream::new(@fabricconfiguration) :
                                  LogStashAutoResizeBuffer::new(@fabricconfiguration)
      end

      events.each do |event|
        # creating document from event
        document = create_event_document(event)

        # Skip if document doesn't contain any items
        next if (document.keys).length < 1

        @logger.trace("Adding event document - " + event.to_s)
        @thread_batch_map[t].batch_event_document(document)
      end
    end

    def close
      @thread_batch_map.each { |thread_id, batcher|
        batcher.close
      }
    end

  end
end; end; end;    