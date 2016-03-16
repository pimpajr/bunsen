require 'rbvmomi'
require 'yaml'
module Bunsen
  class Vsphere < Bunsen::API
    attr_accessor :connection
    attr_reader :vlan_config, :changes, :vlan_spec

    def initialize opts
      fail unless opts.is_a? Hash
      fail unless opts[:user].is_a? String
      fail unless opts[:password].is_a? String
      fail unless opts[:host].is_a? String
      @pgs = {}
      connect opts
    end

    def connect opts
      @connection = RbVmomi::VIM.connect opts
      @connection
    end

    def disconnect
      puts "Closing vSphere Connection"
      @connection.close
    end

    def find_pg port_group, conf
      datacenter = @connection.serviceInstance.find_datacenter conf[:datacenter]
      network = datacenter.network
      resolved_pg = nil
      if @pgs.empty?
        network.each { |f|
          @pgs[f.name] = f
          @pgs_time = Time.now
        }
      elsif Time.now - @pgs_time > 90
        network.each { |f|
          @pgs[f.name] = f
          @pgs_time = Time.now
        }
      end

      @pgs.each { |pg_name,pg|
        case pg_name
        when port_group
          resolved_pg = pg
        end
      }
      resolved_pg
    end

    def find_dvs name, datacenter
      dc = @connection.serviceInstance.find_datacenter datacenter
      net_folder = dc.networkFolder
      dvs = net_folder.childEntity.find { |f| f.name == name }
      dvs
    end

    def dew_config config
      config.each { |type,conf|
        case type
        when /^vlans$/
          parse_vlans conf
          provision @vlan_config
          handle_changes
        end
      }
    end

    def parse_vlans config
      new_config = {}
      config.each { |vlan,opts|
        unless vlan.to_s =~ /^defaults$/
          if opts
            config_copy = opts.dup
          else
            config_copy = {}
          end
          # Build default values allowing certain values to be left
          # out of config.
          # OPTIMIZE make defaults configurable
          if config[:defaults]
            build_config = config[:defaults].merge(config_copy)
          else
            build_config = config_copy
          end
          if build_config[:dvs]
            fail unless build_config[:dvs].is_a? String
            fail unless build_config[:datacenter].is_a? String
            vlan_split = vlan.to_s.split("-")
            build_config[:id] ||= vlan_split[1].to_i
            build_config[:name] ||= vlan.to_s
            build_config[:id] = build_config[:id].is_a?(String) ? build_config[:id].to_i : build_config[:id]

            # Prepare new hash
            name = build_config[:name]
            new_config[name] ||= {}
            valid_keys = [:id,:name,:dvs, :datacenter]
            build_config.each { |key,value|
              case key
              when *valid_keys
                new_config[name][key] = value
              end
            }
          end
        end
      }
      @vlan_config = new_config
    end

    def provision hash
      changes = {}
      vlan_spec = {}
      hash.each { |vlan,conf|

        # setup changes hash
        changes[vlan] ||= {}
        changes[vlan][:old] ||= {}
        changes[vlan][:new] ||= {}
        changes[vlan][:new][:id] = conf[:id]
        # resolve distributed vswitch and portgroup
        pg = find_pg vlan, conf
        if pg
          # pg found, check for changes and reconfig instead of create
          pg_id = pg.config.defaultPortConfig.vlan.vlanId
          pg_name = pg.name
          changes[vlan][:old][:id] = pg_id
          if conf[:id] == pg_id && conf[:name] == pg_name
            changes[vlan][:status] = "none"
          else
            changes[vlan][:status] = "update"
            changes[vlan][:dvs] = conf[:dvs]
            vlan_spec = vlan_spec.merge(reconfig_spec(conf, pg))
          end
        else
          #pg not found, create instead of reconfig
          changes[vlan][:status] = "create"
          changes[vlan][:dvs] = conf[:dvs]
          vlan_spec = vlan_spec.merge(create_spec(conf))
        end
      }
      @vlan_spec = vlan_spec
      @changes = changes
    end

    def create_pg datacenter, dvs_name, opts
      #tasks = []
      #start = Time.now
      opts.each { |vlan,spec|
        puts "\nConfigure %s with:" % vlan
        puts "#{opts.to_yaml}"
        dvs = find_dvs dvs_name, datacenter


        #tasks << dvs.CreateDVPortgroup_Task(:spec => spec)

        #attempts = 5
        #try = (Time.now - start) / 5
        #wait_for_tasks tasks, try, attempts
        #puts 'Spent %.2f seconds creating portgroup %s.' % [(Time.now - start), vlan]
      }
    end

    def reconfig_pg datacenter, dvs_name, opts
      #tasks = []
      #start = Time.now
      opts.each { |vlan,spec|
        puts "\nConfigure %s with:" % vlan
        puts "#{opts.to_yaml}"
        dvs = find_dvs dvs_name, datacenter

        #tasks << dvs.ReconfigureDVPortgroup_Task(spec)

        #attempts = 5
        #try = (Time.now - start) / 5
        #wait_for_tasks tasks, try, attempts
        #puts 'Spent %.2f seconds creating portgroup %s.' % [(Time.now - start), vlan]
      }
    end


    def reconfig_spec conf, pg
      spec = {}
      vlan_id_spec = RbVmomi::VIM.VmwareDistributedVirtualSwitchVlanIdSpec(
          :vlanId => conf[:id]
      )
      dvs_port_spec = RbVmomi::VIM.VMwareDVSPortSetting(
        :vlan => vlan_id_spec
      )
      full_spec = RbVmomi::VIM.DVPortgroupConfigSpec(
        :autoExpand => true,
          :defaultPortConfig => dvs_port_spec,
          :key => pg.key
      )
      spec[conf[:name]] = full_spec
      spec
    end

    def create_spec conf
      spec = {}
      vlan_id_spec = RbVmomi::VIM.VmwareDistributedVirtualSwitchVlanIdSpec(
        :inherited => false,
        :vlanId => conf[:id]
      )
      dvs_port_spec = RbVmomi::VIM.VMwareDVSPortSetting(
        :vlan => vlan_id_spec
      )
      full_spec = RbVmomi::VIM.DVPortgroupConfigSpec(
        :autoExpand => true,
        :defaultPortConfig => dvs_port_spec,
        :name => conf[:name],
        :numPorts => 8,
        :type => "earlyBinding"
      )
      spec[conf[:name]] = full_spec
      spec
    end

    def wait_for_tasks tasks, try, attempts
      obj_set = tasks.map { |task| { :obj => task } }
      filter = @connection.propertyCollector.CreateFilter(
        :spec => {
        :propSet => [{ :type => 'Task',
                     :all  => false,
                     :pathSet => ['info.state']}],
        :objectSet => obj_set
        },
        :partialUpdates => false
      )
      ver = ''
      while true
        result = @connection.propertyCollector.WaitForUpdates(:version => ver)
        ver = result.version
        complete = 0
        tasks.each do |task|
          if ['success', 'error'].member? task.info.state
            complete += 1
          end
        end
        break if (complete == tasks.length)
        if try <= attempts
          sleep 5
          try += 1
        else
          raise "unable to complete Vsphere tasks before timeout"
        end
      end

      filter.DestroyPropertyFilter
      tasks
    end

    def handle_changes
      @changes.each { |vlan,hash|
        case hash[:status]
        when /^create$/
          puts "\nVLAN: %s\nChange Status: %s" % [vlan,hash[:status]]
          @vlan_spec.each { |conf_vlan,conf_spec|
            case vlan
            when conf_vlan
              datacenter = hash[:datacenter]
              dvs_name = hash[:dvs]
              puts "send %s to config" % vlan
              create_pg datacenter, dvs_name, conf_vlan => conf_spec
            end
          }
        when /^update$/
          puts "\nVLAN: %s\nChange Status: %s" % [vlan,hash[:status]]
          @vlan_spec.each { |conf_vlan,conf_spec|
            case vlan
            when conf_vlan
              datacenter = hash[:datacenter]
              dvs_name = hash[:dvs]
              puts "send %s to config" % vlan
              reconfig_pg datacenter, dvs_name, conf_vlan => conf_spec
            end
          }
        when /^none$/
          puts "\nVLAN: %s\nChange Status: %s" % [vlan,hash[:status]]
        end
      }
    end

  end
end
