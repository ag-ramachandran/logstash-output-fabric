
module LogStash; module Outputs; class MicrosoftFabricInternal 
class Client
    def ingest(events)
        raise 'not implemented'
    end
    def self.is_successfully_ingested(response)
        raise 'not implemented'
    end
    def close()
        raise 'not implemented'
    end
end