class ApiKey < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :api_key_hash, presence: true, uniqueness: true
  
  scope :active, -> { where(revoked_at: nil) }
  
  def self.generate_key
    SecureRandom.hex(32)
  end
  
  def self.hash_key(key)
    Digest::SHA256.hexdigest(key)
  end
  
  def revoke!
    update!(revoked_at: Time.current)
  end
  
  def active?
    revoked_at.nil?
  end
end
