class ReportsController < ApplicationController
  before_action :authenticate_user!

  def export
    time_regs_ids = JSON.parse(params[:time_reg_ids])
    csv_data = CSV.generate(headers: true) do |csv|
      # Add CSV header row
      # csv << ['id', 'user_email', 'task_name', 'minutes','created_at', 'updated_at','assigned_task_id', 'user_id', 'membership_id']
      csv << ['date', 'client', 'project', 'task', 'notes', 'minutes', 'first name', 'last name', 'email']
      # Add CSV data rows for each time_reg
      time_regs_ids.each do |time_reg_id|
        time_reg = TimeReg.find(time_reg_id)

        csv << [time_reg.date_worked, time_reg.project.client.name, time_reg.project.name, time_reg.assigned_task.task.name, 
                time_reg.notes, time_reg.minutes, time_reg.user.first_name, time_reg.user.last_name, time_reg.user.email]
      end
    end
    # downloads the report as a .CSV
    send_data csv_data, filename: "#{Time.now.to_i}_time_regs_for_custom_report.csv"
  end

  private

  def get_timeframe_options 
    thisMonthName = I18n.t("date.month_names")[Date.today.month]
    lastMonthName = I18n.t("date.month_names")[Date.today.month-1]
    timeframeOptions = { 
                          "All Time" => 'allTime',
                          "Custom" => 'custom', 
                          "This week" => 'thisWeek',
                          "Last week" => 'lastWeek',
                          "This Month (#{thisMonthName})" => 'thisMonth',
                          "Last month (#{lastMonthName})" => 'lastMonth', 
                        }
  end

  
  # gets all the time_regs for the report with the filters in the report object
  def get_time_regs(report, users, projects, tasks)
    time_regs = TimeReg.includes(:membership, :assigned_task)

    # sets a timeframe unless it is allTime
    if report.timeframe != "allTime"
      time_regs = time_regs.where(date_worked: report.date_start..report.date_end)
    end

    # filters the time_regs to show the correct ones
    time_regs = time_regs.where(membership: {user_id: users, project_id: projects})
                          .where(assigned_task: {task_id: tasks})
                          .order(date_worked: :desc, created_at: :desc)

    time_regs.all
  end

  # groupes the time_regs for the different columns
  def group_time_regs(time_regs, group)

    if group == "task"
      grouped_report = time_regs.group_by { |time_reg| time_reg.task.name }
    elsif group == "user"
      grouped_report = time_regs.group_by { |time_reg| time_reg.user.name }
    elsif group == "date"
      grouped_report = time_regs.group_by { |time_reg| time_reg.date_worked }
    elsif group == "project"
      grouped_report = time_regs.group_by { |time_reg| time_reg.project.name }
    elsif group == "client"
      grouped_report = time_regs.group_by{|time_reg| time_reg.project.client.name}
    end
    grouped_report
  end

  # sets the timeframe for the report if it is custom or allTime
  def set_dates(report)
    puts "SET DATES --------------------"
    if report.timeframe == "allTime"
      report.date_start = nil
      report.date_end = nil
    else
      report = set_timeframe(report)
    end
    report
  end

  # sets the reports timeframe if it is not allTime or custom
  def set_timeframe(report)
    puts "SET TIMEFRAME --------------------"
    timeframe = report.timeframe
    today = Date.today

    new_date_start = nil
    new_date_end = nil

    if timeframe == "thisWeek"
      new_date_start = today.beginning_of_week
      new_date_end = today
    elsif timeframe == "lastWeek"
      new_date_start = today.last_week.beginning_of_week
      new_date_end = today.last_week.end_of_week
    elsif timeframe == "thisMonth"
      new_date_start = today.beginning_of_month
      new_date_end = today
    elsif timeframe == "lastMonth"
      new_date_start = today.last_month.beginning_of_month
      new_date_end = today.last_month.end_of_month
    end
    report.date_start = new_date_start
    report.date_end = new_date_end

    report
  end
end
