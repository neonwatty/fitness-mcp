class User < ApplicationRecord
  has_secure_password validations: false
  
  has_many :api_keys, dependent: :destroy
  has_many :set_entries, dependent: :destroy
  has_many :workout_assignments, dependent: :destroy
  has_many :mcp_audit_logs, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?
  
  def self.from_omniauth(auth)
    user = find_by(email: auth.info.email)
    
    if user
      # Existing user - link OAuth account if not already linked
      if user.provider.blank?
        user.update!(
          provider: auth.provider,
          uid: auth.uid,
          name: auth.info.name,
          image_url: auth.info.image
        )
      end
      user
    else
      # Create new user with OAuth data
      create! do |user|
        user.provider = auth.provider
        user.uid = auth.uid
        user.email = auth.info.email
        user.name = auth.info.name
        user.image_url = auth.info.image
        user.password = SecureRandom.hex(20) # Random password for OAuth users
      end
    end
  end
  
  def oauth_user?
    provider.present?
  end
  
  def has_password?
    password_digest.present?
  end
  
  def admin?
    false # For now, no admin users - can be enhanced later
  end
  
  private
  
  def password_required?
    !oauth_user? || password.present?
  end
end
