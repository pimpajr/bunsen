# Bunsen

Bunsen is a tool for using a single point of configuration (yaml) for systems that typically 
require manual configuration but provide some kind of api to execute configuration on
as well. Currently Bunsen supports executing configuration on the VMware vSphere api using
rbvmomi and Cisco UCS Central xml api using ucsimc. 

### vSphere Support
Currently Bunsen supports configuring portgroups on a specified DVS with a specific vlan
configuration. The values needed for this are name, id, and dvs name. Name and id can be
derived from the key for the individual hash configuration for each vlan. They can
also be specified as values. Since these are the basic values for vlan regardless,
the only additional required value to make this work is the name of the DVS to 
configure the port group on.

### UCS Support
Bunsen supports configuring vlans, vnic templates, and vlan entries in a vnic template in UCS
Central. Vlans and vnic templates are the two items in the configuration for both UCS and vSphere. The vlan entry that gets applied to the vnic template gets derived from the vlan's
configuration, so there's no separate entry for configuring it. 

At this point in time Bunsen does take a couple liberties with UCS configuration. For each
vnic_template, it creates an A and a B entry that use the respective fabrics. With this method, the failover option doesn't get checked and a couple vnic interfaces are created for each template. Bunsen doesn't handle the actual vnic interface creation or update yet though, just the templates. 




## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bunsen'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bunsen

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/bunsen/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
