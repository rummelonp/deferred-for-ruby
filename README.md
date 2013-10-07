# Deferred

[![Build Status](https://travis-ci.org/mitukiii/deferred-for-ruby.png?branch=master)][travis]

[travis]: https://travis-ci.org/mitukiii/deferred-for-ruby

Port of jQuery.Deferred to Ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'deferred-for-ruby'
```

And then execute:

```sh
bundle
```

Or install it yourself as:

```sh
gem install deferred-for-ruby
```

## Usage

```ruby
require 'deferred'

delay_hello = Proc.new do
  d = Deferred.new
  Thread.start do
    sleep 1
    puts :hello
    d.resolve
  end
  d.promise
end

delay_error = Proc.new do
  d = Deferred.new
  Thread.start do
    sleep 1
    d.reject(:error!)
  end
  d.promise
end

hello1 = Proc.new { puts :hello1 }
hello2 = Proc.new { puts :hello2 }

delay_hello.call
  .then(hello1, hello2)
# sleep 1 second...
# => hello
# => hello1

delay_error.call
  .then(hello1, hello2)
# sleep 1 second...
# => hello2

promise1 = delay_hello.call
promise2 = promise1.then(hello1)
# sleep 1 second...
# => hello
# => hello1
promise1 == promise2 # => false

delay_error.call
  .then(hello1)
# do nothing

delay_error.call
  .then(hello1)
  .fail { |error| puts error }
# sleep 1 second...
# => error!

delay_hello.call
  .then(delay_hello)
  .then(delay_hello)
  .then(delay_hello)
# every 1 second say hello

delay_error.call
  .then(hello1,
    Proc.new { |error|
      puts error
      Deferred.new.resolve.promise
    })
  .then(hello1, hello2)
# sleep 1 second...
# => error!
# => hello1

delay_hello_parallel = Proc.new do
  Deferred.when(delay_hello.call, delay_hello.call, delay_hello.call)
end

delay_hello.call
  .then(delay_hello_parallel)
  .then(delay_hello_parallel)
# sleep 1 second...
# => hello
# sleep 1 second...
# => hello
# => hello
# => hello
# sleep 1 second...
# => hello
# => hello
# => hello
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright (c) 2013 [Kazuya Takeshima](mailto:mail@mitukiii.jp). See [LICENSE][license] for details.

[license]: LICENSE.md
