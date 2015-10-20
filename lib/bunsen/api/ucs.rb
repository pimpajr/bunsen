require 'ucsimc'
module Bunsen
  class UCS < Bunsen::API
    attr_accessor :connection
    
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
    
    def find_changes in_dn, out_dn
      changes = {}
      out_dn.each do |odn, ohash|
       in_dn.each do |idn, ihash|
         case odn
         when idn
           changes[idn] ||= {}
           ohash.each do |okey,oval|
             ihash.each do |ikey,ival|
               case okey
               when ikey
                 changes[idn][:old] ||= {}
                 changes[idn][:new] ||= {}
                 if oval == ival
                   puts "%s not changed" % ikey
                 else
                   puts "%s changed" % ikey
                   changes[idn][:old][okey] = oval
                   changes[idn][:new][ikey] = ival
                   
                 end
               end
             end
           end
         end
       end
     end
     changes
    end
    
  end
end
