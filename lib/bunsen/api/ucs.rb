require 'ucsimc'
module Bunsen
  class UCS < Bunsen::API
    attr_accessor :connection
    attr_reader :ucs_vlan_config, :changes
    
    def initialize opts
      fail unless opts.is_a? Hash
      fail unless opts[:user].is_a? String
      fail unless opts[:password].is_a? String
      fail unless opts[:host].is_a? String
      connect opts
    end
    
    def connect opts
      @connection = Ucsimc::IMC.connect opts
      @connection
    end
    
    def disconnect
      @connection.logout
    end
    
    def parse_config config
      parsed = {}
      config.each { |type,config|
        case type
        when /^vlans$/
          @config_class = "fabricVlan"
          parsed = parse_vlans config
        end
      }
      parsed
    end
    
    def parse_vlans config
      new_config = {}
      config.each { |vlan,opts|
        
        # Build default values allowing certain values to be left
        # out of config.
        # OPTIMIZE make defaults configurable
        vlan_split = vlan.to_s.split("-")
        opts[:id] ||= vlan_split[0].to_i.to_s
        opts[:name] ||= vlan
        opts[:mcastPolicyName] ||= "default"
        opts[:defaultNet] ||= "no"
        opts[:dn] = "%s/net-%s" % [opts[:domaingroup],opts[:name]]
          
        # Remove uneeded keys for ucs vlan
        opts.delete(:dvs)
        opts.delete(:domaingroup)
        
        # Prepare new hash
        dn = opts[:dn]
        new_config[dn] ||= {}
        opts.each { |key,value|
          new_config[dn][key] = value 
        }  
      }
      @ucs_vlan_config = new_config
    end
    
    def check_dn hash
      changes = {}
      hash.each { |dn,conf|
        @connection.in_dn = dn
        @connection.resolve_dn
        changes = changes.merge(find_changes({dn => conf}, @connection.out_dn))
        
      }
      @changes = changes
      
    end
    
    def find_changes in_dn, out_dn
      changes = {}
      if out_dn.empty?
        in_dn.each do |idn, ihash|
        changes[idn] ||= {}
        changes[idn][:status] = "create"
        end
      else
        out_dn.each do |odn, ohash|
         in_dn.each do |idn, ihash|
           case odn
           when idn.to_s
             changes[idn] ||= {}
             ohash.each do |okey,oval|
               ihash.each do |ikey,ival|
                 case okey
                 when ikey.to_s
                   changes[idn][:old] ||= {}
                   changes[idn][:new] ||= {}
                   changes[idn][:status] ||= "none"
                   if oval == ival
                     puts "%s not changed" % ikey.to_s
                   else
                     puts "%s changed" % ikey
                     changes[idn][:status] = "update"
                     changes[idn][:old][okey] = oval
                     changes[idn][:new][ikey] = ival
                     
                   end
                 end
               end
             end
           end
         end
       end
      end
      

     changes
    end
    
    def send_config opts
      @connection.in_dn = opts
      @connection.in_class = @config_class
      @connection.config_mo
    end
    
  end
end
