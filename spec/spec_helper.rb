# -*- coding: utf-8 -*-

unless ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

require 'deferred'
require 'rspec'

RSpec.configure do |config|
  config.order = :random
end
