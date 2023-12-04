# encoding: utf-8
require "logstash/outputs/fabricconfiguration"
require "logstash/outputs/fabric/clients/client"


module LogStash; module Outputs; class MicrosoftFabricInternal 
class KustoClient < Client
  def initialize (fabricconfiguration)
    @workers_pool = threadpool
    @logger = logger
    @logger.info('Preparing Kusto resources.')

    kusto_java = Java::com.microsoft.azure.kusto
    apache_http = Java::org.apache.http
    # kusto_connection_string = kusto_java.data.auth.ConnectionStringBuilder.createWithAadApplicationCredentials(ingest_url, app_id, app_key.value, app_tenant)
    # If there is managed identity, use it. This means the AppId and AppKey are empty/nil
    is_managed_identity = (app_id.nil? && app_key.nil?)
    # If it is system managed identity, propagate the system identity
    is_system_assigned_managed_identity = is_managed_identity && 0 == "system".casecmp(managed_identity_id)
    # Is it direct connection
    is_direct_conn = (proxy_host.nil? || proxy_host.empty?)
    # Create a connection string
    kusto_connection_string = if is_managed_identity
        if is_system_assigned_managed_identity
          @logger.info('Using system managed identity.')
          kusto_java.data.auth.ConnectionStringBuilder.createWithAadManagedIdentity(fabricconfiguration.connection_string)  
        else
          @logger.info('Using user managed identity.')
          kusto_java.data.auth.ConnectionStringBuilder.createWithAadManagedIdentity(fabricconfiguration.connection_string, fabricconfiguration.managed_identity_id)
        end
      else
        new kusto_java.data.auth.ConnectionStringBuilder(fabricconfiguration.connection_string)
      end

    #
    @logger.debug(Gem.loaded_specs.to_s)
    # Unfortunately there's no way to avoid using the gem/plugin name directly...
    name_for_tracing = "logstash-output-kusto:#{Gem.loaded_specs['logstash-output-kusto']&.version || "unknown"}"
    @logger.debug("Client name for tracing: #{name_for_tracing}")

    tuple_utils = Java::org.apache.commons.lang3.tuple
    # kusto_connection_string.setClientVersionForTracing(name_for_tracing)
    version_for_tracing=Gem.loaded_specs['logstash-output-kusto']&.version || "unknown"
    kusto_connection_string.setConnectorDetails("Logstash",version_for_tracing.to_s,"","",false,"", tuple_utils.Pair.emptyArray());
    
    @kusto_client = begin
      if is_direct_conn
        kusto_java.ingest.IngestClientFactory.createClient(kusto_connection_string)
      else
        kusto_http_client_properties = kusto_java.data.HttpClientProperties.builder().proxy(apache_http.HttpHost.new(proxy_host,proxy_port,proxy_protocol)).build()
        kusto_java.ingest.IngestClientFactory.createClient(kusto_connection_string, kusto_http_client_properties)
      end
    end

    @ingestion_properties = kusto_java.ingest.IngestionProperties.new(database, table)
    @ingestion_properties.setIngestionMapping(json_mapping, kusto_java.ingest.IngestionMapping::IngestionMappingKind::JSON)
    @ingestion_properties.setDataFormat(kusto_java.ingest.IngestionProperties::DataFormat::JSON)
    @delete_local = delete_local

    @logger.debug('Kusto resources are ready.')
  end

    def ingest(events)
        raise 'not implemented'
    end
    def self.is_successfully_ingested(response)
        raise 'not implemented'
    end
    def close()
        raise 'not implemented'
    end
end # end of class
end ;end ;end 