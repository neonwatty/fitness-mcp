class User < ApplicationRecord
  has_secure_password
  
  has_many :api_keys, dependent: :destroy
  has_many :set_entries, dependent: :destroy
  has_many :workout_assignments, dependent: :destroy
  has_many :mcp_audit_logs, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  
  def admin?
    false # For now, no admin users - can be enhanced later
  end
end
