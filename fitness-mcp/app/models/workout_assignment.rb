class WorkoutAssignment < ApplicationRecord
  belongs_to :user
  
  validates :assignment_name, presence: true
  validates :config, presence: true
  
  scope :scheduled, -> { where.not(scheduled_for: nil) }
  scope :upcoming, -> { where("scheduled_for > ?", Time.current) }
  
  def config_json
    JSON.parse(config) if config.present?
  rescue JSON::ParserError
    {}
  end
  
  def config_json=(value)
    self.config = value.to_json
  end
end
