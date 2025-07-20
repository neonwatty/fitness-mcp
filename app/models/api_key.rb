class ApiKey < ApplicationRecord
  belongs_to :user
  has_many :mcp_audit_logs, dependent: :destroy
  
  validates :name, presence: true
  validates :api_key_hash, presence: true, uniqueness: true
  
  scope :active, -> { where(revoked_at: nil) }
  
  # Encrypt the API key value before storing
  def api_key_value=(value)
    if value.present?
      super(Base64.encode64(value))
    else
      super(nil)
    end
  end
  
  # Decrypt the API key value when reading
  def api_key_value
    encoded_value = super
    if encoded_value.present?
      Base64.decode64(encoded_value)
    else
      nil
    end
  end
  
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
  
  # Alias for find_by_key for backwards compatibility
  def self.find_by_api_key_value(key)
    find_by_key(key)
  end
  
  # Get the decrypted API key value
  def decrypted_api_key_value
    api_key_value
  end
end
