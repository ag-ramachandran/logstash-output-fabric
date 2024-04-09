jruby -S gem install bundler -v 2.4.19        
jruby -S bundle install
./gradlew vendor
jruby -S gem build *.gemspec
/softwares/logstash/bin/logstash-plugin  install logstash-output-ms-fabric-0.0.1.gem
/softwares/logstash/bin/logstash -f /code/fabric-connectors/logstash-output-fabric/tests/logstash-test.conf
