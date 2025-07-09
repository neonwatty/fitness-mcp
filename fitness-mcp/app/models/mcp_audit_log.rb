class McpAuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :api_key
  
  validates :tool_name, presence: true
  validates :arguments, presence: true
  validates :result_success, inclusion: { in: [true, false] }
  validates :timestamp, presence: true
  
  scope :recent, -> { order(timestamp: :desc) }
  scope :successful, -> { where(result_success: true) }
  scope :failed, -> { where(result_success: false) }
  scope :for_tool, ->(tool_name) { where(tool_name: tool_name) }
  scope :since, ->(time) { where('timestamp > ?', time) }
  
  def self.log_tool_usage(user:, api_key:, tool_name:, arguments:, result_success:, ip_address: nil)
    create!(
      user: user,
      api_key: api_key,
      tool_name: tool_name,
      arguments: arguments.to_json,
      result_success: result_success,
      ip_address: ip_address,
      timestamp: Time.current
    )
  end
  
  def parsed_arguments
    JSON.parse(arguments) if arguments.present?
  rescue JSON::ParserError
    {}
  end
end
