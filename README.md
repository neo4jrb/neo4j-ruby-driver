# Neo4j::Driver

home  :: https://github.com/neo4jrb/neo4j-ruby-driver

This repository contains 2 implementation of a neo4j driver for ruby:
- `neo4j-java-driver` based on official java implementation. It provides a thin wrapper over java driver (only in jruby).
- `neo4j-ruby-driver` based on [seabolt](https://github.com/neo4j-drivers/seabolt) and [ffi](https://github.com/ffi/ffi). Available on all rubies (including jruby) and all platforms supported by seabolt.

## Installation

### neo4j-java-driver

Add this line to your application's Gemfile:

```ruby
gem 'neo4j-java-driver'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install neo4j-java-driver
    
### neo4j-ruby-driver

As a prerequisite [seabolt](https://github.com/neo4j-drivers/seabolt) must be installed.
 
On macOS

    $ brew install michael-simons/homebrew-seabolt/seabolt 
    
On other systems please follow the instructions to install either from package or source. Make sure the libseabolt17 ends up in a system lib path e.g. /usr/local/lib
 
Add this line to your application's Gemfile:

```ruby
gem 'neo4j-ruby-driver'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install neo4j-ruby-driver

## Usage

Both drivers implement identical API and can be used interchangeably. The API is to highest possible degree consistent with the official java driver. 
At this moment [The Neo4j Drivers Manual v1.7](https://neo4j.com/docs/driver-manual/1.7/) along with the ruby version of the [code fragments](https://github.com/neo4jrb/neo4j-ruby-driver/blob/master/docs/dev_manual_examples.rb) and the ruby specs provide the only documentation. 

[Neo4j Java Driver 1.7 API](https://neo4j.com/docs/api/java-driver/current/) can be helpful as well..

## Development

This gem includes 2 different implementations: java driver based and another one using seabolt via ffi

For java driver based:

    $ bin/setup
    
FFI based same as above but with SEABOLT_LIB variable set (e.g. on Mac OSX):

    $ SEABOLT_LIB=~/seabolt/build/dist/lib/libseabolt17.dylib bin/setup 
     
Please note that seabolt has to be installed separately: https://github.com/neo4j-drivers/seabolt      

## Testing

To run the tests the following tools need to be installed:

    $ brew install python
    $ wget https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py --user
    $ python3 -m pip install --user git+https://github.com/klobuczek/boltkit@1.3#egg=boltkit
    $ neoctrl-install -e 4.0.0 servers
    $ neoctrl-configure servers/neo4j-enterprise-4.0.0 dbms.directories.import=
    $ neoctrl-set-initial-password password servers/neo4j-enterprise-4.0.0
    $ neoctrl-start servers/neo4j-enterprise-4.0.0

## Contributing

Suggestions, improvements, bug reports and pull requests are welcome on GitHub at https://github.com/neo4jrb/neo4j-ruby-driver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

