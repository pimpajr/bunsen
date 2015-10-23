require 'yaml'
require 'hashie'
require 'bunsen'

module Bunsen
  class Honeydew
    attr_accessor :connected_apis, :config, :auth
    
    def initialize opts
      opts[:bunsen_home] ||= "/etc/bunsen"
      opts[:config] ||= "honeydew.yaml"
      opts[:auth] ||= "auth.yaml"
      
      @bunsen_home = opts[:bunsen_home]  
      @config = "%s/%s" % [@bunsen_home, opts[:config]]
      @auth = "%s/%s" % [@bunsen_home, opts[:auth]]
        
      load_auth
      load_config
      load_apis
      test
    end
    
    def test
      test = instance_variable_get("@"+@connected_apis[0])
      puts test
    end
    
    def load_auth
      auth = load_file @auth
      @auth = Hashie.symbolize_keys auth
    end
    
    def load_config
      config = load_file @config
      @config = Hashie.symbolize_keys config
    end
    
    def load_file file
      if File.exists? file
        yaml = YAML::load_file file
      else
        raise "Could not load file: %s" % file
      end
      yaml
    end
    
    def load_apis
      connected = []
      @auth.each { |api, auth_hash|
        api_resolved = Bunsen::API.create api => auth_hash
        instance_variable_set("@" + api.to_s, api_resolved)
        instance_variable_get("@" + api.to_s)
        self.class.send(:attr_accessor, api)
        connected << api.to_s
        
      }
      @connected_apis = connected
    end
    
    def config_ucs
      @connected_apis.each { |api|
        #case api
        #when /^ucs$/
          puts "\n\#\#\#\# #{api} Config Begin \#\#\#\#"
          api = instance_variable_get("@" + api)
          api.do_config @config
          puts "\n\#\#\#\# #{api} Config End \#\#\#\#"
        #when /^vsphere$/
        #  puts "\n\#\#\#\# vSphere Config Begin \#\#\#\#"
        #  vsphere = instance_variable_get("@" + api)
        #  vsphere.parse_config @config
        #  puts "\n\#\#\#\# vSphere Config End \#\#\#\#"
        #end
      }
    end
    
    
  end
end