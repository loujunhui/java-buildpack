# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'
require 'rexml/document'
require 'rexml/formatters/pretty'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Tomcat lifecycle support.
  class TomcatRedisStore < JavaBuildpack::Component::VersionedDependencyComponent
    include JavaBuildpack::Container

    # @macro base_component_compile
    def compile
      puts "*********** come in TomcatRedisStore compile support? #{support?}"
      if supports?
        download_jar(jar_name, tomcat_lib)
        mutate_context
      end
    end

    # @macro base_component_release
    def release
    end

    protected

    def supports?
      @application.services.one_service? FILTER, KEY_HOST_NAME, KEY_PORT, KEY_PASSWORD
    end

    private

    FILTER = /session-replication/.freeze

    FLUSH_VALVE_CLASS_NAME = 'com.gopivotal.manager.SessionFlushValve'.freeze

    KEY_HOST_NAME = 'hostname'.freeze

    KEY_PASSWORD = 'password'.freeze

    KEY_PORT = 'port'.freeze

    PERSISTENT_MANAGER_CLASS_NAME = 'org.apache.catalina.session.PersistentManager'.freeze

    REDIS_STORE_CLASS_NAME = 'com.gopivotal.manager.redis.RedisStore'.freeze

    def add_manager(context)
      manager = context.add_element 'Manager', 'className' => PERSISTENT_MANAGER_CLASS_NAME
      add_store manager
    end

    def add_store(manager)
      credentials = @application.services.find_service(FILTER)['credentials']

      manager.add_element 'Store',
                          'className'          => REDIS_STORE_CLASS_NAME,
                          'host'               => credentials[KEY_HOST_NAME],
                          'port'               => credentials[KEY_PORT],
                          'database'           => @configuration['database'],
                          'password'           => credentials[KEY_PASSWORD],
                          'timeout'            => @configuration['timeout'],
                          'connectionPoolSize' => @configuration['connection_pool_size']
    end

    def add_valve(context)
      context.add_element 'Valve', 'className' => FLUSH_VALVE_CLASS_NAME
    end

    def context_xml
      @droplet.sandbox + 'conf/context.xml'
    end

    def formatter
      formatter         = REXML::Formatters::Pretty.new(4)
      formatter.compact = true
      formatter
    end

    def jar_name
      "redis_store-#{@version}.jar"
    end

    def mutate_context
      puts '       Adding Redis-based Session Replication'

      document = context_xml.open { |file| REXML::Document.new file }
      context  = REXML::XPath.match(document, '/Context').first

      add_valve context
      add_manager context

      context_xml.open('w') do |file|
        formatter.write document, file
        file << "\n"
      end
    end

  end

end
