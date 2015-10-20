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
        
      @config = "%s/%s" % [opts[:bunsen_home], opts[:config]]
      @auth = "%s/%s" % [opts[:bunsen_home], opts[:auth]]
        
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
      @connected_apis.each do |api|
        case api
        when /^ucs$/
          ucs = instance_variable_get("@" + api)
          ucs.parse_config @config
          ucs.check_dn ucs.ucs_vlan_config
          ucs.changes.each do |dn,hash|
            case hash[:status]
            when /^create$/, /^update$/
              puts "\nDN: %s\nChange Status: %s" % [dn,hash[:status]]
              ucs.ucs_vlan_config.each do |conf_dn,conf_opts|
                case dn
                when conf_dn
                  ucs.send_config conf_dn => conf_opts
                end
              end
            when /^none$/
              puts "\nDN: %s\nChange Status: %s" % [dn,hash[:status]]
            end
          end
        end
      end
    end
    
    
  end
end