class TimeRegsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_time_reg, only: [ :toggle_active, :edit_modal, :update ]
  before_action :set_projects, only: [ :index, :new_modal, :create, :edit_modal ]
  before_action :set_chosen_date, only: [ :index, :new_modal, :create, :edit_modal ]

  require "activerecord-import/base"
  require "csv"
  include TimeRegsHelper

  def index
    @time_regs_week = current_user.time_regs.between_dates(@chosen_date.beginning_of_week, @chosen_date.end_of_week)
    @time_regs = @time_regs_week.on_date(@chosen_date)
    @total_minutes_day = @time_regs.sum(:minutes)
    @minutes_by_day = minutes_by_day_of_week(@chosen_date, current_user)
    @time_reg = TimeReg.new(date_worked: @chosen_date)
    @total_minutes_week = @time_regs_week.sum(:minutes)
  end

  def new_modal
    @time_reg = TimeReg.new
  end

  def create
    # gives the time_reg all the attributes
    if Project.exists?(time_reg_params[:project_id])
      @project = Project.find(time_reg_params[:project_id])
      @time_reg = @project.time_regs.build(time_reg_params.except(:project_id, :minutes_string))
      membership = @project.memberships.find_by(user_id: current_user.id, project_id: @project.id)
      @time_reg.membership_id = membership.id
    else
      @time_reg = TimeReg.new(time_reg_params.except(:project_id, :minutes_string))
    end

    @time_reg.active = @time_reg.minutes.zero? # start as active?
    @time_reg.updated = Time.now

    respond_to do |format|
      if @time_reg.save
        format.turbo_stream
        format.html { redirect_to root_path(date: @time_reg.date_worked), notice: "Time entry has been created" }
      else
        format.turbo_stream
        format.html { redirect_to root_path(date: @time_reg.date_worked), status: :unprocessable_entity }
      end
    end
  end

  def edit
    @time_reg = TimeReg.find(params[:id])
    @projects = current_user.projects
    @assigned_tasks = Task.joins(:assigned_tasks)
                          .where(assigned_tasks: { project_id: @time_reg.project.id })
                          .pluck(:name, "assigned_tasks.id")
  end

  def update
    respond_to do |format|
      if @time_reg.update(time_reg_params.except(:project_id, :minutes_string))
        format.turbo_stream
        format.html { redirect_to root_path(date: @time_reg.date_worked), notice: "Time entry has been updated" }
      else
        format.turbo_stream
        format.html { redirect_to root_path(date: @time_reg.date_worked), status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @time_reg = TimeReg.find(params[:id])

    if @time_reg.destroy
      redirect_to root_path(date: @time_reg.date_worked)
      flash[:notice] = "Time entry has been deleted"
    else
      @projects = current_user.projects
      @assigned_tasks = Task.joins(:assigned_tasks)
                            .where(assigned_tasks: { project_id: @time_reg.project.id })
                            .pluck(:name, "assigned_tasks.id")

      flash[:alert] = "cannot delete time entry"
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @project = @time_reg.project

    if @time_reg.minutes >= TimeReg::MINUTES_IN_A_DAY
      return redirect_to root_path(date: @time_reg.date_worked), alert: "Time entry cannot exceed 24 hours"
    end

    update_time_reg(current_status: @time_reg.active)
  end

  # exports the time_regs in a project to a .CSV
  def export
    project = Project.find(params[:project_id])
    client = project.client
    time_regs = project.time_regs.includes(
      :task,
      :user,
      membership: [ :user ],
      assigned_task: %i[project task],
      project: :client
    )
    csv_data = CSV.generate(headers: true) do |csv|
      # Add CSV header row
      csv << [ "date", "client", "project", "task", "notes", "minutes", "first name", "last name", "email" ]
      # Add CSV data rows for each time_reg
      time_regs.each do |time_reg|
        csv << [ time_reg.date_worked, client.name, project.name, time_reg.assigned_task.task.name,
                time_reg.notes, time_reg.minutes, time_reg.user.first_name, time_reg.user.last_name, time_reg.user.email ]
      end
    end
    send_data csv_data, filename: "#{Time.now.to_i}_time_regs_for_#{project.name}.csv"
  end

  # changes the selection tasks to show tasks from a specific project
  def update_tasks_select
    @tasks = Task.joins(:assigned_tasks).where(assigned_tasks: { project_id: params[:project_id] }).pluck(:name,
                                                                                                          "assigned_tasks.id")
    render partial: "/time_regs/select", locals: { tasks: @tasks }
  end

  def edit_modal
    @assigned_tasks = Task.assigned_tasks(@time_reg.project.id)
  end

  private

  def time_reg_params
    params.require(:time_reg).permit(:notes, :minutes, :assigned_task_id, :date_worked, :project_id, :minutes_string)
  end

  def update_time_reg(current_status:)
    if current_status
      worked_minutes = (Time.now.to_i - @time_reg.updated.to_i) / 60
      @time_reg.minutes = [ @time_reg.minutes + worked_minutes, TimeReg::MINUTES_IN_A_DAY ].min
    else
      @time_reg.updated = Time.now
    end

    @time_reg.active = !current_status

    if @time_reg.save
      flash[:success] = {
        title: "Success", body: "Timer has been toggled #{current_status ? "off": "on"}"
      }

      redirect_to root_path(date: @time_reg.date_worked)
    end
  end

  def set_time_reg
    @time_reg = TimeReg.find(params[:time_reg_id] || params[:id])
  end

  def set_projects
    @projects ||= current_user.projects
    end
  def set_chosen_date
    @chosen_date = params.has_key?(:date) ? Date.parse(params[:date]) : Date.today
  end
end
