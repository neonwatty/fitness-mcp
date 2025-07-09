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
  api_key = test_user.api_keys.find_or_create_by(name: 'Development API Key') do |key|
    key.api_key_hash = BCrypt::Password.create(SecureRandom.hex(32))
  end
  
  if api_key.persisted?
    puts "API key created: #{api_key.name}"
  end
end
