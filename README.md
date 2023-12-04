# Logstash Output Plugin for Fabric (Kusto)

![build](https://github.com/Azure/logstash-output-fabric/workflows/build/badge.svg?branch=master)
[![Gem](https://img.shields.io/gem/v/logstash-output-fabric.svg)](https://rubygems.org/gems/logstash-output-fabric)
[![Gem](https://img.shields.io/gem/dt/logstash-output-fabric.svg)](https://rubygems.org/gems/logstash-output-fabric)



The [Logstash](https://github.com/elastic/logstash) plugin works by leveraging the [Kusto logstash plugin](https://github.com/Azure/logstash-output-fabric) and enables processing of events from Logstash into **Kusto in Microsoft Fabric** database for  analysis. 

## Requirements

- Logstash version 8.5+. [Installation instructions](https://www.elastic.co/guide/en/logstash/current/installing-logstash.html) 
- Kusto in Microsoft Fabric cluster with a Kusto database. Read [Create a database](https://learn.microsoft.com/en-us/fabric/real-time-analytics/create-database) for more information.
- AAD Application credentials with permission to ingest data into the database created above in Microsoft Fabric. Read [Creating an AAD Application](https://docs.microsoft.com/en-us/azure/kusto/management/access-control/how-to-provision-aad-app) for more information.

## Installation and Configuration

Refer the [installation](logstash-output-fabric/README.md/#installation) and [configuration](logstash-output-fabric/README.md/#configuration) sections for more information.

More information about configuring Logstash can be found in the [logstash configuration guide](https://www.elastic.co/guide/en/logstash/current/configuration.html)

Note that managed identity is not supported on Kusto in Microsoft Fabric. You must use AAD Application credentials to ingest data into Kusto in Microsoft Fabric.

### Available Configuration Keys

The complete list of configuration keys available for the plugin are as documented for the Kusto plugin [here](logstash-output-fabric/README.md/#available-configuration-keys).


### Release Notes and versions

Releases and bugfixes are documented in the [CHANGELOG.md](logstash-output-fabric/CHANGELOG.md) file.


## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, and complaints.
Programming is not a required skill. It is more important to the community that you are able to contribute.
For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.
