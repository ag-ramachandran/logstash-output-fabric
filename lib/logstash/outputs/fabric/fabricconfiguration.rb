# encoding: utf-8
module LogStash; module Outputs; class MicrosoftFabricInternal
class FabricOutputConfiguration
    def initialize(connection_string, plugin_flush_interval, max_items, retransmission_time, compress_data, managed_identity_id, logger)
        @connection_string = connection_string
        @plugin_flush_interval = plugin_flush_interval
        @max_items = max_items
        @retransmission_time = retransmission_time
        @compress_data = compress_data
        @logger = logger
    # Delay between each resending of a message
        @RETRANSMISSION_DELAY = 2
        @MIN_MESSAGE_AMOUNT = 100
    end
	
	def validate_configuration()
        required_configs = { "connection_string" => @connection_string}
        required_configs.each { |name, conf|
            if conf.nil?
                print_missing_parameter_message_and_raise(name)
            end
            if conf.empty?
                raise ArgumentError, "Connection string is empty."
            end
        }

        if @retransmission_time < 0
            raise ArgumentError, "retransmission_time must be a positive integer."
        end
        if @max_items < @MIN_MESSAGE_AMOUNT
            raise ArgumentError, "Setting max_items to value must be greater then #{@MIN_MESSAGE_AMOUNT}."
        end
        @logger.info("Fabric configuration was found valid.")
        # If all validation pass then configuration is valid
        return  true
    end # def validate_configuration


    def print_missing_parameter_message_and_raise(param_name)
        @logger.error("Missing a required setting for the fabric output plugin:
            output {
                fabric {
                #{param_name} => # SETTING MISSING
                ...
                }
            }
        ")
        raise ArgumentError, "The setting #{param_name} is required."
    end

    def RETRANSMISSION_DELAY
        @RETRANSMISSION_DELAY
    end

    def MAX_SIZE_BYTES
        @MAX_SIZE_BYTES
    end

    def retransmission_time
        @retransmission_time
    end

    def logger
        @logger
    end

    def connection_string
        @connection_string
    end

    def plugin_flush_interval
        @plugin_flush_interval
    end

    def max_items
        @max_items
    end

    def compress_data
        @compress_data
    end
end #FabricOutputConfiguration
end ;end ;end 