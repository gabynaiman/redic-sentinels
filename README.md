# Redic::Sentinels

[![Gem Version](https://badge.fury.io/rb/redic-sentinels.svg)](https://rubygems.org/gems/redic-sentinels)
[![Build Status](https://travis-ci.org/gabynaiman/redic-sentinels.svg?branch=master)](https://travis-ci.org/gabynaiman/redic-sentinels)
[![Coverage Status](https://coveralls.io/repos/gabynaiman/redic-sentinels/badge.svg?branch=master)](https://coveralls.io/r/gabynaiman/redic-sentinels?branch=master)
[![Code Climate](https://codeclimate.com/github/gabynaiman/redic-sentinels.svg)](https://codeclimate.com/github/gabynaiman/redic-sentinels)
[![Dependency Status](https://gemnasium.com/gabynaiman/redic-sentinels.svg)](https://gemnasium.com/gabynaiman/redic-sentinels)

Redic::Sentinels is a wrapper for the Redis client that fetches configuration details from sentinels.

Based on [soveran/redisent](https://github.com/soveran/redisent)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redic-sentinels'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redic-sentinels

## Usage

```ruby
sentinels = [
  'localhost:26379',
  'localhost:26380',
  'localhost:26381'
]

redis = Redic::Sentinels.new sentinels: sentinels, 
                             master_name: 'mymaster', 
                             db: 1, # optional (default: 0)
                             password: 'pass' # optional

redis.call 'PING' # => 'PONG'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gabynaiman/redic-sentinels.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

