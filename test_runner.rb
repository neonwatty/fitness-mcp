#!/usr/bin/env ruby

# Simple test runner script to run Rails tests
require 'bundler/setup'

# Set Rails environment
ENV['RAILS_ENV'] = 'test'

# Load Rails application
require_relative 'config/environment'

puts "Rails environment: #{Rails.env}"
puts "Rails version: #{Rails.version}"
puts "Ruby version: #{RUBY_VERSION}"

# Try to run a simple test
require 'rails/test_help'

# Run all tests
exit_code = system('bin/rails test --verbose')
puts "Test run completed with exit code: #{exit_code}"