ENV["RAILS_ENV"] ||= "test"

# Configure SimpleCov for code coverage
require 'simplecov'

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Helper methods for tests
    def create_user(email: nil, password: 'password123')
      # Generate unique email if none provided or if the default test email is used
      if email.nil? || email == 'test@example.com'
        email = "test#{SecureRandom.hex(4)}@example.com"
      end
      User.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
    end

    def create_api_key(user:, name: 'Test API Key')
      key = ApiKey.generate_key
      key_hash = ApiKey.hash_key(key)
      api_key_record = user.api_keys.create!(
        name: name,
        api_key_hash: key_hash
      )
      [api_key_record, key]
    end

    def api_headers(api_key)
      { 'Authorization' => "Bearer #{api_key}" }
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include ActiveSupport::TestCase::InstanceMethods if defined?(ActiveSupport::TestCase::InstanceMethods)
    
    def create_user(email: nil, password: 'password123')
      # Generate unique email if none provided or if the default test email is used
      if email.nil? || email == 'test@example.com'
        email = "test#{SecureRandom.hex(4)}@example.com"
      end
      User.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
    end

    def create_api_key(user:, name: 'Test API Key')
      key = ApiKey.generate_key
      key_hash = ApiKey.hash_key(key)
      api_key_record = user.api_keys.create!(
        name: name,
        api_key_hash: key_hash
      )
      [api_key_record, key]
    end

    def api_headers(api_key)
      { 'Authorization' => "Bearer #{api_key}" }
    end
    
    def create_user_with_api_key(email: 'test@example.com', password: 'password123')
      user = create_user(email: email, password: password)
      api_key_record, key = create_api_key(user: user)
      # Store the key value as an instance variable for tests to access
      api_key = user.api_keys.first
      api_key.instance_variable_set(:@key, key)
      api_key.define_singleton_method(:key) { @key }
      user
    end
  end
end
