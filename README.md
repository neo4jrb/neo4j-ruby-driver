# Neo4j::Driver

Proposal for an API for neo4j ruby driver. This gem contains reference implementation in jruby with most of the features
completed.
The proposed API is heavilly inspired but the java and javascipt driver. Please add comments and suggestions if you feel there 
is better idiomatic alternative in ruby.

The file `doc/dev_manual_examples_spec.rb` contains all the code examples included in the 
[Chapter 4. Drivers][https://neo4j.com/docs/developer-manual/3.4/drivers/] of the Developer Manual and should be 
reviewed side by side with that manual.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'neo4j-ruby-driver'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install neo4j-ruby-driver

## Usage

Refer to https://neo4j.com/docs/developer-manual/3.4/drivers/.

This gem includes 2 different implementations: java driver based (jRuby) and another one using seabolt via ffi (MRI, jRuby)
     
Please note that seabolt has to be installed separately from: https://github.com/neo4j-drivers/seabolt, alongside with it's dependencies.
For seabolt library itself we recommend picking one of already released packages, appropriate for your platform: https://github.com/neo4j-drivers/seabolt/releases     

For MRI version, gem will not work if `SEABOLT_LIB` environment variable is not set. 
For jRuby version if `SEABOLT_LIB` is not set neo4j java driver will be used..

## Development

After checking out the repo, run `bin/setup` to install dependencies. 

### Runing tests
To setup neo4j instance for testing:

Check: https://neo4j.com/download-center/#community for latest version and run:
   
    $ rake neo4j:install[neo4j_version]
    
Make sure neo4j always listens on ports used in test suite:    
    
     $ rake neo4j:config[development,7474]
     
Setup password for neo4j instance:     
     
     $ ./db/neo4j/development/bin/neo4j-admin set-initial-password password
     
Run neo4j with authentication enabled:
    
    $ rake neo4j:enable_auth neo4j:start     
    
Before running RSpec tests you may have to set your own `NEO4J_BOLT_URL` URI as an environment variable or it will
fallback to `bolt://localhost:7472`, also `SEABOLT_LIB` needs to be set if you're going to run it on MRI/jRuby with seabolt ([more](#usage)). 

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Local deployments

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
    
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/neo4j-driver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


[https://neo4j.com/docs/developer-manual/3.4/drivers/]: https://neo4j.com/docs/developer-manual/3.4/drivers/

[https://neo4j.com/docs/developer-manual/3.4/drivers/]: https://neo4j.com/docs/developer-manual/3.4/drivers/
