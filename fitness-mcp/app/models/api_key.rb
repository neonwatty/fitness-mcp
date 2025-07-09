class ApiKey < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :api_key_hash, presence: true, uniqueness: true
  
  scope :active, -> { where(revoked_at: nil) }
  
  def self.generate_key
    SecureRandom.hex(16)
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
  
  def self.find_by_key(key)
    return nil if key.blank?
    
    hashed_key = hash_key(key)
    active.find_by(api_key_hash: hashed_key)
  end
end
