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
      dew_config
      disconnect_apis
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
    
    # Dynamically connect to api's defined in auth file
    # using Bunsen::API.create, which supports dynamic loading
    # of custom api files in the api folder using the top level
    # hash name in the auth config file
    #
    # Current default supported api's are:
    # vsphere using rbvmomi
    # ucs central using ucsimc
    
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
    
    # Dynamically load any api's connected with
    # load_apis using Bunsen::API.create, which supports
    # dynamic loading of custom files in the api folder
    #
    # Custom api classes must have a do_config method that ultimately
    # executes configuration on the api.
    # This class must also parse the config hash and merge the defaults
    # The class should also track changes and only take action when
    # changes are detected.
    
    def dew_config
      start = Time.now
      @connected_apis.each { |api_name|
        puts "\n\#\#\#\# #{api_name} Config Begin \#\#\#\#"
        api = instance_variable_get("@" + api_name)
        api.dew_config @config
        puts "\n\#\#\#\# #{api_name} Config End \#\#\#\#"
      }
      puts "Took %.2f seconds to resolve and configure." % (Time.now - start)
    end
    
    def disconnect_apis
      @connected_apis.each { |api_name|
        puts "\n\#\#\#\# #{api_name} Disconnect Begin \#\#\#\#"
        api = instance_variable_get("@" + api_name)
        api.disconnect
        puts "\n\#\#\#\# #{api_name} Disconnect End \#\#\#\#"
      }
    end
    
    
  end
end