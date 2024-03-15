class TimeReg < ApplicationRecord
  MINUTES_IN_A_DAY = 1.day.in_minutes.to_i

  before_validation :set_default_minutes

  validates :notes, format: { without: /\r|\n/, message: "Line breaks are not allowed" }

  belongs_to :membership
  belongs_to :assigned_task

  has_one :project, through: :assigned_task
  has_one :task, through: :assigned_task, source: :task
  has_one :user, through: :membership
  has_one :client, through: :project

  validates :notes, length: { maximum: 255 }
  validates :minutes, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1440 }
  validates :membership, presence: true
  validates :assigned_task, presence: true
  validates :assigned_task_id, presence: true
  validates :date_worked, presence: true

  scope :for_report, ->(client_ids, project_ids, user_ids, task_ids) {
    joins(:user, :project, :task, :client)
      .where(
        client: { id: client_ids },
        project: { id: project_ids },
        user: { id: user_ids },
        task: { id: task_ids },
      )
  }

  def set_default_minutes
    self.minutes ||= 0
  end
end
