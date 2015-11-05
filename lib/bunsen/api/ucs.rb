require 'ucsimc'
require 'yaml'
module Bunsen
  class UCS < Bunsen::API
    attr_accessor :connection
    attr_reader :vlan_config, :changes
    
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
      puts "Closing UCS Connection"
      @connection.logout
    end
    
    def dew_config config
      parsed = {}
      config.each { |type,content|
        case type
        when /^vnic_templates$/
          @config_class = "vnicLanConnTempl"
          parse type, content, config
          provision @ucs_config
          handle_changes @ucs_config
        when /^vlans$/
          @config_class = "fabricVlan"
          parse type, content, config
          provision @ucs_config
          handle_changes @ucs_config
          @config_class = "vnicEtherIf"
          provision @assoc_vnic
          handle_changes @assoc_vnic
           
        end
      }
    end
    
    def handle_changes config
      @changes.each { |dn,hash|
        case hash[:status]
        when /^create$/, /^update$/
          puts "\nDN: %s\nChange Status: %s" % [dn,hash[:status]]
          config.each { |conf_dn,conf_opts|
          case dn
          when conf_dn
            send_config conf_dn => conf_opts
          end
          }
        when /^none$/
          puts "\nDN: %s\nChange Status: %s" % [dn,hash[:status]]
        end
        }
    end
    
    def parse type, content, config
      new_config = {}
      @assoc_vnic = {}
      content.each { |item,opts|
        if opts
          config_copy = opts.dup
        else
          config_copy = {}
        end
        case type
        when /^vlans$/
          unless item.to_s =~ /^defaults$/
            if content[:defaults]
              build_config = content[:defaults].merge(config_copy)
            else
              build_config = config_copy
            end
            vlan_split = item.to_s.split("-")
            
            build_config[:id] ||= vlan_split[1].to_i.to_s
            build_config[:name] ||= item.to_s
            build_config[:dn] = "%s/net-%s" % [build_config[:domaingroup],build_config[:name]]
            valid_keys = [:id,:name,:mcastPolicyName,:defaultNet,:dn]
            vlan_vnic = vlan_associate_vnic(build_config, config)
            @assoc_vnic = @assoc_vnic.merge(vlan_vnic)
              
            dn = build_config[:dn]
            new_config[dn] ||= {}
  
            build_config.each { |key,value|
              case key
              when *valid_keys
                new_config[dn][key] = value
              end
            }
          end
        when /^vnic_templates$/
          unless item =~ /^defaults$/
            vnic_temp = {}
            if content[:defaults]
              build_config = content[:defaults].merge(config_copy)
            else
              build_config = config_copy
            end
            vnic_temp = build_config.dup
            if vnic_temp[:switchId]
              vnic_temp[:name] = "%s-%s"  % [item.to_s, vnic_temp[:switchId].downcase]
              if vnic_temp[:org] =~ /\/$/
                vnic_temp[:dn] = "%slan-conn-templ-%s" % [vnic_temp[:org], vnic_temp[:name]]
              else
                vnic_temp[:dn] = "%s/lan-conn-templ-%s" % [vnic_temp[:org], vnic_temp[:name]]
              end
              vnic_temp[:identPoolName] = "%s-%s" % [vnic_temp[:identPoolName], vnic_temp[:switchId].split("-")[0]]
              valid_keys = [:name,:dn,:mtu,:switchId,:nwCtrlPolicyName,:identPoolName,:pinToGroupName,:policyLevel,:policyOwner,:qosPolicyName,:statsPolicyName,:target,:templType]
                                      
              dn = vnic_temp[:dn]
              new_config[dn] ||= {}
                                    
              vnic_temp.each { |key,value|
                case key
                when *valid_keys
                  new_config[dn][key] = value
                end
              }
            else
              ('A'..'B').each { |fabric_id|
                vnic_temp = build_config.dup
                vnic_temp[:name] = "%s-%s"  % [item.to_s, fabric_id.downcase]
                if vnic_temp[:org] =~ /\/$/
                  vnic_temp[:dn] = "%slan-conn-templ-%s" % [vnic_temp[:org], vnic_temp[:name]]
                else
                  vnic_temp[:dn] = "%s/lan-conn-templ-%s" % [vnic_temp[:org], vnic_temp[:name]]
                end
                vnic_temp[:switchId] = fabric_id
                vnic_temp[:identPoolName] = "%s-%s" % [vnic_temp[:identPoolName], fabric_id]
                valid_keys = [:name,:dn,:mtu,:switchId,:nwCtrlPolicyName,:identPoolName,:pinToGroupName,:policyLevel,:policyOwner,:qosPolicyName,:statsPolicyName,:target,:templType]
                          
                dn = vnic_temp[:dn]
                new_config[dn] ||= {}
                      
                vnic_temp.each { |key,value|
                  case key
                  when *valid_keys
                    new_config[dn][key] = value
                  end
                }
              }
            end
            
            
            
          end
        end

      }
      @ucs_config = new_config
    end
    
    def provision hash
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
        
      # catch an empty out_dn first so it gets processed
      # as a create before trying to be compared
      # an empty hash here indicates the dn in the config
      # doesn't resolve to anything in the ucs, thus it needs
      # to be created
        
      if out_dn.empty?
        in_dn.each { |idn, ihash|
          changes[idn] ||= {}
          changes[idn][:status] = "create"
        }
      else
        
        # compare the out_dn and in_dn hashes
        # out_dn is the full value returned from ucs
        # in_dn is the shortened to the required readwrite
        # settings, so many won't match but important ones will
        # when keys match, compare  the values and store
        # for reporting purposes
        
        out_dn.each { |odn, ohash|
         in_dn.each { |idn, ihash|
           case odn
           when idn.to_s
             changes[idn] ||= {}
             ohash.each { |okey,oval|
               ihash.each { |ikey,ival|
                 case okey
                 when ikey.to_s
                   changes[idn][:old] ||= {}
                   changes[idn][:new] ||= {}
                   changes[idn][:status] ||= "none"
                   if oval == ival
                     #puts "\nDN: %s\n%s: no change" % [idn.to_s, ikey.to_s]
                   else
                     #puts "\nDN: %s\n%s: changed to %s" % [idn.to_s,ikey.to_s, ival]
                     changes[idn][:status] = "update"
                     changes[idn][:old][okey] = oval
                     changes[idn][:new][ikey] = ival
                     
                   end
                 end
               }
             }
           end
         }
        }
      end
      

     changes
    end
    

    
    def vlan_associate_vnic build_config, config
      final_config = {}
      vnic_conf = {}
      vnic_tmpl = config[:vnic_templates].reject {|h| h =~ /^defaults$/}

      if build_config[:vnic_template].is_a? Array
        build_config[:vnic_template].each { |vnic_temp|
          vnic_tmpl.each { |tmpl,opts|
            case vnic_temp
            when tmpl.to_s
              if opts
                if opts[:switchId]
                  final_config = final_config.merge(build_vlan(build_config, opts[:switchId], vnic_temp))
                else
                  ('A'..'B').each { |fabric_id|
                    final_config = final_config.merge(build_vlan(build_config, fabric_id, vnic_temp))
                  }
                end
              else
                ('A'..'B').each { |fabric_id|
                  final_config = final_config.merge(build_vlan(build_config, fabric_id, vnic_temp))
                }
              end
            end 
          }
        }
      else
        vnic_tmpl.each {|tmpl,opts|
          case build_config[:vnic_template]
          when tmpl.to_s
            if opts
              if opts[:switchId]
                final_config = final_config.merge(build_vlan(build_config, opts[:switchId], build_config[:vnic_template]))
              else
                ('A'..'B').each { |fabric_id|
                  final_config = final_config.merge(build_vlan(build_config, fabric_id, build_config[:vnic_template]))
                }
              end
            else
              ('A'..'B').each { |fabric_id|
                final_config = final_config.merge(build_vlan(build_config, fabric_id, build_config[:vnic_template]))
              }
            end
          end
        }
      end
      final_config
    end
    
    def build_vlan build_config, fabric_id, vnic_temp
      new_config = {}
      vnic_conf = {}
      vnic_conf[:switchId] = fabric_id
      if build_config[:vnic_template_native].is_a? Array
        build_config[:vnic_template_native].each { |native_template|
          case native_template
          when vnic_temp
            vnic_conf[:defaultNet] = 'yes'
          else
            vnic_conf[:defaultNet] = 'no'
          end
        }
      else
        case build_config[:vnic_template_native]
        when vnic_temp
          vnic_conf[:defaultNet] = 'yes'
        else
          vnic_conf[:defaultNet] = 'no'
        end
      end
      vnic_conf[:dn] = "%s/lan-conn-templ-%s-%s/if-%s" %[build_config[:vnic_org],vnic_temp,fabric_id.downcase, build_config[:name]]
      vnic_conf[:name] = build_config[:name]
                          
      valid_keys = [:dn,:defaultNet,:name]
      dn = vnic_conf[:dn]
      new_config[dn] ||= {}
      vnic_conf.each { |key,value|
        case key
        when *valid_keys
          new_config[dn][key] = value
        end
      }
      new_config
    end
    
    def send_config opts
      puts "\n\nStarting #{@config_class} Task"
      opts.each { |dn,conf|
        puts "\nConfiguring %s with:" % dn.to_s
        puts "#{opts.to_yaml}"
      }
      @connection.in_dn = opts
      @connection.in_class = @config_class
      start = Time.now
      #@connection.config_mo
      puts "\nSpent %.2f seconds creating %s %s." % [(Time.now - start), @config_class, opts.keys[0]]
    end
    
  end
end
