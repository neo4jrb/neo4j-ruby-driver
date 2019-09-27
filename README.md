# Neo4j::Driver

home  :: https://github.com/neo4jrb/neo4j-ruby-driver

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. 
In order to run test by running `rake spec` you may have to set your own `NEO4J_BOLT_URL` URI or it will
fallback to `bolt://localhost:7687`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

This gem includes 2 different implementations: java driver based and another one using seabolt via ffi

For java driver based:

    $ gem install hoe
    $ gem install hoe-bundler
    $ gem install hoe-gemspec
    $ rake clean bundler:gemfile[,true] gem:spec
    $ bundle
    $ rake  
    
FFI based: same as above but with SEABOLT_LIB variable set

    $ SEABOLT_LIB=~/seabolt/build/dist/lib/libseabolt17.dylib 
     
Please note that seabolt for now has to be installed separately: https://github.com/neo4j-drivers/seabolt      
    
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/neo4j-driver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


[https://neo4j.com/docs/developer-manual/3.4/drivers/]: https://neo4j.com/docs/developer-manual/3.4/drivers/

[https://neo4j.com/docs/developer-manual/3.4/drivers/]: https://neo4j.com/docs/developer-manual/3.4/drivers/
