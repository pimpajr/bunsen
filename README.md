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
Primary usage of this gem involves a couple configuration files. By default, Bunsen
looks in /etc/bunsen for honeydew.yaml and auth.yaml. The configuration path and file
names can be set at execution. 

### Auth
The auth.yaml file contains the api and authentication details for each api. 

### Honeydew
The honeydew.yaml is where vlans and vnic templates (currently) will be configured.
The following instructions should help to understand the options. (WIP: creating example still)

#### Basic VLAN
The defaults takes care of most of the configuration for the site. In most cases,
adding a vlan should simply be an empty hash, like so:
```
m-0010-this-vlan:

m-0011-that-vlan:
```
The name and id gets derived from this string, so no additional configuration
is necessary. That said you can still specify `name:` and `id:` to overide this
behavior, like so:

```
m-0010-this-vlan:        #title
  name: m-0010-this-vlan #attribute
  id: '10'               #attribute
```
Here I've given some comments to provide some arbitrary labels for the following 
explanations.

This sets the same configuration that's automatically done with just the formatted
title. However,  using name and id attributes overrides the parsing of the title
entirely. For example,

```
m-0010-this-vlan:        #title
  name: that           #attribute
  id: '11'               #attribute
```
This vlan would end  up being named 'that' with an id of '11' regardless of what the
title says.

#### Advanced VLAN
Advanced usage stems into configuring a vlan that needs to exist in multiple vnic 
templates and/or the vlan needs to be set native in one or more of the vnic  templates it's assigned to. The 'attributes' `vnic_template:` and
`vnic_template_native:` can either be a single string or an array. When setting
`vnic_template_native:` to a value other than 'no', it should be set to one of 
the names in `vnic_template:` string or array. See below for an example:

```
m-0010-this-vlan:
  vnic_template:
    - this-vnic-template
    - that-vnic-template
  vnic_template_native: this-vnic-template
```
This example demonstrates the two attributes outlined above. In this case,
`vnic_template:` is an array of templates the vlan is to be assigned to.
`vnic_template_native:` on the other hand isn't an array, but indicates that
the vlan should be set to native in the 'this-vnic-template' vNIC template. Because 'that-vnic-template' is not included in `vnic_template_native:` the vlan will
use the default `vnic_template_native:` value of 'no'. 

#### vNIC Template
vNIC configuration is just like VLAN configuration with some different values. The
defaults once again come in handy here providing for much the same configuration
as a VLAN. There are some important differences to be aware of. The vNIC template takes a single entry and creates two vNIC templates for the A and B UCS fabrics. 
For example:

```
this-vnic-template:

that-vnic-template:
```
This configuration is just like the VLAN. It uses the defaults provided in
`defaults:` and creates 'this-vnic-template-a', 'this-vnic-template-b', 
'that-vnic-template-a', and 'that-vnic-template-b'. To override any attributes of
`defaults:` just include them in the individual template configuration like so:

```
this-vnic-template:
  org: org-root/org-THIS
```
If `org:` is set in `defaults:` then this entry would override whatever is set in
`defaults:`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/bunsen/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
