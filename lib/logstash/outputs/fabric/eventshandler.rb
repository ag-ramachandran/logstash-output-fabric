# encoding: utf-8
require "logstash/outputs/fabricconfiguration"

module LogStash
  module Outputs
    class MicrosoftSentinelOutputInternal
      class EventsHandler

        def initialize(fabricconfiguration)
          @fabricconfiguration = fabricconfiguration
          @logger = fabricconfiguration.logger
        end

        def handle_events(events)
          raise "Method handle_events not implemented"
        end

        def close
          raise "Method close not implemented"
        end

        # In case that the user has defined key_names meaning that he would like to a subset of the data,
        # we would like to insert only those keys.
        # If no keys were defined we will send all the data
        def create_event_document(event)
          document = {}
          event_hash = event.to_hash
          document = event_hash
          return document
        end
        # def create_event_document

      end
    end
  end
end