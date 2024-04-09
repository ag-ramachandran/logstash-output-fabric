GEM_VERSION = File.read(File.expand_path(File.join(File.dirname(__FILE__), "VERSION"))).strip unless defined?(GEM_VERSION)

Gem::Specification.new do |s|
  s.name          = 'logstash-output-ms-fabric'
  s.version       = GEM_VERSION
  s.licenses      = ['Apache-2.0']
  s.summary       = 'A plugin for Logstash to send events to an MS Fabric platform'
  s.description   = 'This is a Logstash output plugin used to write events to an MS Fabric platform. It supports both EventStreams and Kusto Query Language Data Base (KQLDB) endpoints.'
  s.homepage      = 'https://github.com/ag-ramachandran/logstash-output-fabric'
  s.authors       = ['Ramachandran A G']
  s.email         = 'ramacg'
  s.require_paths = ['lib', 'vendor/jar-dependencies']

  # Files
  s.files = Dir['lib/**/*', 'spec/**/*', 'vendor/**/*','vendor/jar-dependencies/**/*.jar', 'vendor/jar-dependencies/**/*.rb', '*.gemspec', '*.md', 'CONTRIBUTORS', 'Gemfile', 'LICENSE', 'VERSION', 'NOTICE']

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Metadata "logstash_* => .." are special flags to indicate this a logstash plugin
  s.metadata = {
    "logstash_plugin" => "true",
    "logstash_group" => "output",
    "source_code_uri" => "https://github.com/ag-ramachandran/logstash-output-fabric",
    "allowed_push_host" => "https://rubygems.org"
  }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  #s.add_runtime_dependency "logstash-core", ">= 6.5.0"
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'logstash-codec-json'
  s.add_runtime_dependency "logstash-output-kusto", '~> 2.0', '>= 2.0.5'
  s.add_development_dependency 'logstash-devutils'
  # Jar dependencies
  s.add_development_dependency 'jar-dependencies'
end
