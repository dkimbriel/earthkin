class MeetingConfirmationsController < ApplicationController
  layout 'public'

  def show
    @event = Event.includes(:eventable, :location).find_by!(confirmation_token: params[:token])
    @application = @event.eventable
    @program = @application.program
    @location = @event.location

    # Parse the selected date from query params
    @selected_date = Time.zone.at(params[:date].to_i) if params[:date].present?

    # Check if already confirmed
    if @event.status != 'pending_selection'
      render :already_confirmed
      return
    end

    # Validate selected date is one of the proposed dates
    unless @selected_date && @event.proposed_dates_as_times.any? { |d| d.to_i == @selected_date.to_i }
      render :invalid_date
      return
    end
  end

  def confirm
    @event = Event.includes(:eventable, :location).find_by!(confirmation_token: params[:token])
    @application = @event.eventable
    @program = @application.program
    @location = @event.location

    # Check if already confirmed
    if @event.status != 'pending_selection'
      render :already_confirmed
      return
    end

    # Parse the selected date
    selected_date = Time.zone.at(params[:date].to_i)

    begin
      @event.confirm_date_selection!(selected_date)
      @application.schedule_meeting! if @application.respond_to?(:schedule_meeting!)
      @selected_date = selected_date

      # Send confirmation email to parent
      email_service = EmailTrackingService.new(@application)
      email_service.send_email('EnrollmentMailer', 'meeting_scheduled', [@event.id], { event_id: @event.id })

      render :confirmed
    rescue ArgumentError => e
      flash[:error] = e.message
      redirect_to meeting_confirmation_path(params[:token], date: params[:date])
    end
  end
end
