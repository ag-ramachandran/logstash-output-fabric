# encoding: utf-8
# A class just having all the configurations wrapped into a seperate object

java_import com.azure.messaging.eventhubs.EventData
java_import com.azure.core.amqp.AmqpRetryMode
java_import com.azure.core.amqp.AmqpRetryOptions
java_import com.azure.messaging.eventhubs.EventData
java_import com.azure.messaging.eventhubs.EventDataBatch
java_import com.azure.messaging.eventhubs.EventHubClientBuilder
java_import com.azure.messaging.eventhubs.EventHubProducerClient

java_import java.time.Duration
java_import java.io.IOException
java_import java.nio.ByteBuffer
java_import java.nio.charset.Charset
java_import java.lang.IllegalArgumentException

module LogStash
    module Outputs
        module FabricInternal
            class FabricEventStreamClient
                def initialize(connection_string, connection_retry_count, logger)
                    @logger = logger
                    # Build Event Hubs client connection string
                    # The case for EventStreams is quite straightforward. Just target the endpoint and use the EventBatch abstraction to send data
                    custom_retry_options = AmqpRetryOptions.new().setMaxRetries(connection_retry_count).setTryTimeout(Duration.ofSeconds(60))
                    @producer_client = EventHubClientBuilder.new().connectionString(connection_string).retryOptions(custom_retry_options).buildProducerClient()
                    @event_data_batch = @producer_client.createBatch()
                    @logger.info("EventStream client initialized")
                end # def initialize
                def close()
                  @producer_client.close()
                end
                def ingest(event, payload)
                    begin
                      # Create EventData object and convert payload to bytes
                      if event.nil? || payload.nil?
                        @logger.warn("Event or payload is nil, ignoring the record")
                      else
                        payload_bytes = ByteBuffer::wrap(payload.to_java_bytes)
                        if payload_bytes.nil? || payload_bytes.remaining() == 0
                          @logger.warn("Event or payload is empty, ignoring the record")
                        else
                          @logger.info("Adding message :: "+ payload )                           
                          eh_data = EventData.new(payload_bytes)
                          if @event_data_batch.tryAdd(eh_data)
                            @logger.debug('> Added record to batch')
                          else
                            # if the batch is full, send it and then create a new batch
                            @producer_client.send(@event_data_batch);
                            @event_data_batch = producer_client.createBatch();
                            if @event_data_batch.tryAdd(eh_data)
                                @logger.info('Added record to batch that was left over from previous batch')
                            else
                                raise IllegalArgumentException.new("Event is too large for an empty batch. Max size: "+ @event_data_batch.getMaxSizeInBytes());          
                            end # nested if
                          end # top level if
                        end
                      end # outer if
                      @logger.info("Sending batch of : "+ @event_data_batch.getCount().to_s ) 
                      if @event_data_batch.getCount() > 0 
                        @producer_client.send(@eh_data_batch);
                      end # reminder if
                    rescue => e
                      @logger.warn("Error sending event", :exception => e, :event => event)
                    end #rescue
                  end # def ingest
            end # end of class
end ;end ;end