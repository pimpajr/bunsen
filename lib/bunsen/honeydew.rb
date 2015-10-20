require 'yaml'
require 'hashie'
require 'bunsen'

module Bunsen
  class Honeydew    
    
    def initialize opts
      opts[:bunsen_home] ||= "/etc/bunsen"
      #opts[:config] ||= "honeydew.yaml"
      opts[:auth] ||= "auth.yaml"
        
      #@config = "%s/%s" % [opts[:bunsen_home], opts[:config]]
      @auth = "%s/%s" % [opts[:bunsen_home], opts[:auth]]
        
      load_auth
      #load_config
      
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
      @auth.each { |api, auth_hash|
        api_resolved = Bunsen::API.create api => auth_hash
        puts api_resolved
        instance_variable_set("@" + api.to_s, api_resolved)
        instance_variable_get("@" + api.to_s)
        self.class.send(:attr_accessor, api)
        
      }
    end
    
    
  end
end