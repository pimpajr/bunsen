require 'rbvmomi'
module Bunsen
  class Vsphere < Bunsen::API
    attr_accessor :connection
    
    def initialize opts
      fail unless opts.is_a? Hash
      fail unless opts[:user].is_a? String
      fail unless opts[:password].is_a? String
      fail unless opts[:host].is_a? String
      connect opts
    end
    
    def connect opts
      @connection = RbVmomi::VIM.connect opts
      @connection
    end
    
    
  end
end
