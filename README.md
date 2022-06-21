# Neo4j::Driver

home  :: https://github.com/neo4jrb/neo4j-ruby-driver

This repository contains 2 implementation of a neo4j driver for ruby:
- based on official java implementation. It provides a thin wrapper over the java driver (only on jruby).
- pure ruby implmementation. Available on all ruby versions >= 3.1.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'neo4j-ruby-driver'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install neo4j-ruby-driver

## Server Compatibility

The compatibility with Neo4j Server versions is documented in the [Neo4j Knowledge Base](https://neo4j.com/developer/kb/neo4j-supported-versions/).

## Usage

The API is to highest possible degree consistent with the official java driver. 
At this moment [The Neo4j Drivers Manual v4.4](https://neo4j.com/docs/java-manual/current/) along with the ruby version of the [code fragments](https://github.com/neo4jrb/neo4j-ruby-driver/blob/master/docs/dev_manual_examples.rb) and the ruby specs provide the only documentation. 

[Neo4j Java Driver 4.3 API](https://neo4j.com/docs/api/java-driver/current/) can be helpful as well..

## Development

This gem includes 2 different implementations: java driver wrapper and pure ruby driver

    $ bin/setup 
     
## Testing

To run the tests the following tools need to be installed:
    $ brew install python
    $ pip3 install --user git+https://github.com/klobuczek/boltkit@1.3#egg=boltkit
    $ neoctrl-install -e 4.4.5 servers
    $ neoctrl-configure servers/neo4j-enterprise-4.4.5 dbms.directories.import= dbms.default_listen_address=::
    $ neoctrl-set-initial-password pass servers/neo4j-enterprise-4.4.5
    $ neoctrl-start servers/neo4j-enterprise-4.4.5

To run the tests:
```console
$ bin/setup
$ rspec spec
```

Known errors:

1. In case of heap space memory error (`org.neo4j.driver.exceptions.DatabaseException: Java heap space`), you should limit the dbms memory, for example:

```console
$ neoctrl-configure servers/neo4j-enterprise-4.4.5 dbms.memory.pagecache.size=600m dbms.memory.heap.max_size=600m dbms.memory.heap.initial_size=600m dbms.directories.import= dbms.connectors.default_listen_address=::
```

2. When using command `pip3 install --user git+https://github.com/klobuczek/boltkit@1.3#egg=boltkit`, if you have m1 mac chip, you may get error when pip3 tries to install `cryptography`. Steps to take in that case (reference https://stackoverflow.com/a/70074869/2559490)

```console
$ pip uninstall cffi
$ python -m pip install --upgrade pip
$ pip install cffi
$ pip install cryptography
```

## Contributing

Suggestions, improvements, bug reports and pull requests are welcome on GitHub at https://github.com/neo4jrb/neo4j-ruby-driver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

