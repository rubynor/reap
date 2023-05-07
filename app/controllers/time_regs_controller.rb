class TimeRegsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_membership

  require 'activerecord-import/base'
  require 'csv'
  
  def new 
    @project = Project.find(params[:project_id])    
    @assigned_tasks = Task.select('name, assigned_tasks.id, project_id, task_id')
    .joins(:assigned_tasks).where("project_id = #{@project.id}")        
    @membership = @project.memberships.find_by(user_id: current_user.id)
    @time_reg = @project.time_regs.new
  end

  def create  
    @project = Project.find(params[:project_id])   
    @time_reg = @project.time_regs.build(time_reg_params)
    @membership = @project.memberships.find_by(user_id: current_user.id)
    
    @assigned_tasks = Task.select('name, assigned_tasks.id, project_id, task_id')
    .joins(:assigned_tasks).where("project_id = #{@project.id}")  

    @time_reg.active = false
    @time_reg.updated = Time.now
    if @time_reg.save
        flash[:notice] = "Time entry has been created"
        redirect_to @project
    else
        render :new, status: :unprocessable_entity
    end   
  end

  def edit
    @project = Project.find(params[:project_id])
    @assigned_tasks = Task.select('DISTINCT name, assigned_tasks.id, project_id, task_id')
        .joins(:assigned_tasks).where("project_id = #{@project.id}")    
    @membership = @project.memberships.find_by(user_id: current_user.id)
    @time_reg = @project.time_regs.find(params[:id])
  end

  def update
    @project = Project.find(params[:project_id])
    @time_reg = @project.time_regs.find(params[:id])
    @membership = @project.memberships.find_by(user_id: current_user.id)

    if @time_reg.update(time_reg_params)
      redirect_to @project
      flash[:notice] = "Time entry has been updated"
    else
      flash[:alert] = "cannot update time entry" 
      render :new, status: :unprocessable_entity
    end
  end

  def destroy 
  @project = Project.find(params[:project_id])
  @time_reg = @project.time_regs.find(params[:id])

  if @time_reg.destroy
    redirect_to @project
    flash[:notice] = "Time entry has been deleted"
    else
      flash[:alert] = "cannot delete time entry" 
      render :new, status: :unprocessable_entity
    end
  end

  def toggle_active
    @project = Project.find(params[:project_id])
    @time_reg = @project.time_regs.find(params[:time_reg_id])

    if @time_reg.active
      new_timestamp = Time.now

      old_time = @time_reg.updated.to_i
      new_time = new_timestamp.to_i

      worked_minutes = (new_time - old_time) / 60

      @time_reg.minutes += worked_minutes
      @time_reg.active = false
    else
      @time_reg.updated = Time.now
      @time_reg.active = true
    end
    
    if @time_reg.save
      redirect_to [@client, @project]
    else
      render :new, status: :unprocessable_entity
    end
  end

  def export
    @project = Project.find(params[:project_id])
    @client = Client.find(@project.client_id)
    @time_regs = @project.time_regs
    csv_data = CSV.generate(headers: true) do |csv|
      # Add CSV header row
      # csv << ['id', 'user_email', 'task_name', 'minutes','created_at', 'updated_at','assigned_task_id', 'user_id', 'membership_id']
      csv << ['date', 'client', 'project', 'task', 'notes', 'minutes', 'first name', 'last name', 'email']
      # Add CSV data rows for each time_reg
      @time_regs.each do |time_reg|
        membership = Membership.find(time_reg.membership.id)

        date = time_reg.date_worked
        client = @client.name
        project = @project.name
        task = Task.find(time_reg.assigned_task.task_id).name
        notes = time_reg.notes
        minutes = time_reg.minutes
        first_name = User.find(time_reg.membership.user_id).first_name
        last_name = User.find(time_reg.membership.user_id).last_name
        email = User.find(time_reg.membership.user_id).email

        csv << [date, client, project, task, notes, minutes, first_name, last_name, email]
      end
    end
    send_data csv_data, filename: "#{Time.now.to_i}_time_regs_for_#{@project.name}.csv"
  end

  def import
    @project = Project.find(params[:project_id])
    imported_time_regs = []

    if params[:file].blank?
      flash[:alert] = "Please select a file to import."
      redirect_to project_path(@project) and return
    end

    file = params[:file].read
    begin
      CSV.parse(file, headers: true) do |row|
        time_reg_params = row.to_hash.slice('date', 'client', 'project', 'task', 'notes', 'minutes', 'first name', 'last name', 'email')

        puts "csv:"
        puts time_reg_params
        time_reg_params['date_worked'] = row['date']
        time_reg_params.delete('date')
        puts time_reg_params
        puts "WOAA"

        # Client-håndtering
        client = row['client']
        if (!Client.exists?(name: client))
          @client = Client.new(client)
          puts "SWAG" 
        end
        time_reg_params.delete('client')

        # Project-håndtering
        project = row['project']
        if (!Project.exists?(name: project))
          @project = Project.new(project)
          puts "SWAG!!" 
        end
        time_reg_params.delete('project')

        # Task-håndtering
        task = row['task']
        if (!Task.exists?(name: task))
          @tasks = Task.all
          @task = @tasks.new(name: task)
          @task.save
        else
          @task = Task.find_by(name: task)
        end

        puts time_reg_params 
        puts @task.id
        if (@project.assigned_tasks.find_by(task_id: @task.id) == nil)
          @assigned_task = @project.assigned_tasks.build(@project.id, @task.id)
          puts "waaahh"
        else
          @assigned_task = @project.assigned_tasks.find_by(task_id: @task.id)
        end
        time_reg_params['assigned_task_id'] = @assigned_task.id
        time_reg_params.delete('task')
        puts time_reg_params
        puts "----------------------------"

        time_reg_params.delete('first name')
        time_reg_params.delete('last name')

        email = row['email']
        @user = User.find_by(email: email)
        @membership = Membership.find_by(user_id: @user.id)
        time_reg_params.delete('email')
        time_reg_params['membership_id'] = @membership.id

        puts time_reg_params
        puts "ÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆÆ"
        imported_time_reg = @project.time_regs.new(time_reg_params)
        if imported_time_reg.valid?
          imported_time_regs << imported_time_reg
        else
          Rails.logger.debug "Invalid time entry: #{imported_time_reg.errors.full_messages}"
        end
      end

      if imported_time_regs.present?
        TimeReg.import(imported_time_regs)
        flash[:notice] = "Time entries imported successfully."
      else
        flash[:alert] = "No valid time entries found in the file."
      end
      redirect_to project_path(@project)
      rescue StandardError => e
        flash[:alert] = "There was an error importing the file: #{e.message}"
        redirect_to project_path(@project)
    end
  end

  private
  def time_reg_params
    params.require(:time_reg).permit(:notes, :minutes, :assigned_task_id, :membership_id, :date_worked)
  end

  def ensure_membership
    project = Project.find(params[:project_id])

    if !project.memberships.exists?(user_id: current_user)
      flash[:alert] = "Access denied"
      redirect_to root_path
    end
  end
end
