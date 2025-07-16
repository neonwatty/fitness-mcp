class WorkoutAssignment < ApplicationRecord
  belongs_to :user
  
  validates :assignment_name, presence: true
  validates :config, presence: true
  
  scope :active, -> { all } # For now, all assignments are considered active
  scope :scheduled, -> { where.not(scheduled_for: nil) }
  scope :upcoming, -> { where("scheduled_for > ?", Time.current).order(:scheduled_for) }
  scope :past, -> { where("scheduled_for < ?", Time.current).order(:scheduled_for) }
  scope :for_date, ->(date) { where(scheduled_for: date.beginning_of_day..date.end_of_day) }
  
  def config_json
    JSON.parse(config) if config.present?
  rescue JSON::ParserError
    {}
  end
  
  def config_json=(value)
    self.config = value.to_json
  end
end
