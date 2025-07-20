# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create test user for easy development/testing
test_user = User.find_or_create_by(email: 'test@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end

puts "Test user created: #{test_user.email}"
puts "Password: password123"

# Create an API key for the test user
if test_user.persisted?
  # Delete existing API key to create a fresh one
  test_user.api_keys.where(name: 'Development API Key').destroy_all
  
  # Generate a new API key
  api_key_value = ApiKey.generate_key
  key_hash = ApiKey.hash_key(api_key_value)
  
  api_key = test_user.api_keys.create!(
    name: 'Development API Key',
    api_key_hash: key_hash,
    api_key_value: api_key_value
  )
  
  puts "API key created: #{api_key.name}"
  puts "API key value: #{api_key_value}"
  puts "COPY THIS API KEY: #{api_key_value}"
end
