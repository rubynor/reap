class ReportsController < ApplicationController

  before_action :authenticate_user!

  def new
    set_form_data
    @structured_report_data = {}

    @clients = Client.all
    @projects = Project.all
    @tasks = Task.all
    @users = User.all
  end

  def update
    set_form_data

    scope_client_ids = @client_ids.presence || Client.ids
    scope_project_ids = @project_ids.presence || Project.ids
    scope_user_ids = @user_ids.presence || User.ids
    scope_task_ids = @task_ids.presence || Task.ids

    time_regs = TimeReg.with_report_scope(scope_client_ids, scope_project_ids, scope_user_ids, scope_task_ids)
                       .where(date_worked: (@start_date..@end_date))

    @structured_report_data = TimeRegsPresenter.new(time_regs).report_data(
      title: nil,
      keys: [:client, :project, :task, :user]
    )

    @clients = Client.all
    @projects = Project.all
    @tasks = Task.all
    @users = User.all

    if turbo_frame_request?
      render partial: "form", locals: {
        clients: @clients,
        projects: @projects,
        tasks: @tasks,
        users: @users,
        structured_report_data: @structured_report_data,
        start_date: @start_date,
        end_date: @end_date,
        client_ids: @client_ids,
        project_ids: @project_ids,
        task_ids: @task_ids,
        user_ids: @user_ids,
      }
    end
  end

  # exports the the report as a .CSV
  def export
    time_regs = JSON.parse(params[:time_regs_hash])
    csv_data = CSV.generate(headers: true) do |csv|
      # Add CSV header row
      csv << ['date', 'client', 'project', 'task', 'notes', 'minutes', 'first name', 'last name', 'email']
      # Add CSV data rows for each time_reg
      time_regs.each do |time_reg|
        csv << [time_reg['date'], time_reg['client'], time_reg['project'], time_reg['task'],
                time_reg['notes'], time_reg['minutes'], time_reg['user_first_name'], time_reg['user_last_name'], time_reg['user_email']]
      end
    end
    # downloads the report as a .CSV
    send_data csv_data, filename: "#{Time.now.to_i}_time_regs_for_custom_report.csv"
  end

  private

  def report_params
    return params unless params[:report]
    params.require(:report).permit(:start_date, :end_date, client_ids: [], project_ids: [], task_ids: [], user_ids: [])
  end

  def set_form_data
    @start_date = Date.parse(report_params[:start_date]) if report_params[:start_date].present?
    @end_date = Date.parse(report_params[:end_date]) if report_params[:end_date].present?

    @client_ids = report_params[:client_ids].to_a.map(&:to_i)
    @project_ids = report_params[:project_ids].to_a.map(&:to_i)
    @user_ids = report_params[:user_ids].to_a.map(&:to_i)
    @task_ids = report_params[:task_ids].to_a.map(&:to_i)
  end

  # returns a hash of the correrct timeframe options
  def get_timeframe_options
    thisMonthName = I18n.t('date.month_names')[Date.today.month]
    lastMonthName = I18n.t('date.month_names')[Date.today.month - 1]
    timeframeOptions = {
      'All Time' => 'allTime',
      'Custom' => 'custom',
      'This week' => 'thisWeek',
      'Last week' => 'lastWeek',
      "This Month (#{thisMonthName})" => 'thisMonth',
      "Last month (#{lastMonthName})" => 'lastMonth'
    }
  end

  # gets all the time_regs for the report with the filters in the report object
  def get_time_regs(report, users, projects, tasks)
    # includes tables to decrease the number of queries
    time_regs = TimeReg.includes(
      :task,
      :user,
      membership: [:user],
      assigned_task: %i[project task],
      project: :client
    )

    # sets a timeframe unless it is allTime
    time_regs = time_regs.where(date_worked: report.date_start..report.date_end) unless report.timeframe == 'allTime'

    # filters the time_regs to show the correct ones
    time_regs.where(membership: { user_id: users, project_id: projects })
                         .where(assigned_task: { task_id: tasks })
                         .order(date_worked: :desc, created_at: :desc)
  end

  # groupes the time_regs for the different columns
  def group_time_regs(time_regs_hash, group)
    if group == 'task'
      grouped_report = time_regs_hash.group_by { |time_reg| time_reg[:task] }
    elsif group == 'user'
      grouped_report = time_regs_hash.group_by { |time_reg| time_reg[:user] }
    elsif group == 'date'
      grouped_report = time_regs_hash.group_by { |time_reg| time_reg[:date] }
    elsif group == 'project'
      grouped_report = time_regs_hash.group_by { |time_reg| time_reg[:project] }
    elsif group == 'client'
      grouped_report = time_regs_hash.group_by { |time_reg| time_reg[:client] }
    end
    grouped_report
  end

  # sets the timeframe for the report if it is custom or allTime
  def set_dates(report)
    if report.timeframe == 'allTime'
      report.date_start = nil
      report.date_end = nil
    else
      report = set_timeframe(report)
    end
    report
  end

  # sets the reports timeframe if it is not allTime or custom
  def set_timeframe(report)
    timeframe = report.timeframe
    today = Date.today

    if timeframe == 'thisWeek'
      new_date_start = today.beginning_of_week
      new_date_end = today
    elsif timeframe == 'lastWeek'
      new_date_start = today.last_week.beginning_of_week
      new_date_end = today.last_week.end_of_week
    elsif timeframe == 'thisMonth'
      new_date_start = today.beginning_of_month
      new_date_end = today
    elsif timeframe == 'lastMonth'
      new_date_start = today.last_month.beginning_of_month
      new_date_end = today.last_month.end_of_month
    end
    report.date_start = new_date_start
    report.date_end = new_date_end

    report
  end
end
