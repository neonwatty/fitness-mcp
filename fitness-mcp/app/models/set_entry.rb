class SetEntry < ApplicationRecord
  belongs_to :user
  
  validates :exercise, presence: true
  validates :reps, presence: true, numericality: { greater_than: 0 }
  validates :weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :for_exercise, ->(exercise) { where(exercise: exercise) }
  scope :recent, -> { order(timestamp: :desc) }
  
  before_validation :set_default_timestamp
  
  private
  
  def set_default_timestamp
    self.timestamp ||= Time.current
  end
end
