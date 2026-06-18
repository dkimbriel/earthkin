module Api
  class EventsController < BaseController
    def index
      events = Event.includes(:eventable, :location)
                   .order(scheduled_at: :desc)

      events = events.where(status: params[:status]) if params[:status].present?
      events = events.where(event_type: params[:event_type]) if params[:event_type].present?

      # Filter by eventable (e.g., enrollment_applications)
      if params[:eventable_type].present? && params[:eventable_id].present?
        events = events.where(eventable_type: params[:eventable_type], eventable_id: params[:eventable_id])
      end

      render json: events.as_json(
        include: {
          eventable: {
            only: [:id, :status],
            methods: [:full_parent_name, :full_child_name]
          },
          location: { only: [:id, :name, :address] }
        }
      )
    end

    def show
      event = Event.includes(:eventable, :location).find(params[:id])
      render json: event.as_json(
        include: {
          eventable: {},
          location: {}
        }
      )
    end

    def create
      # Use workflow service if it's a meet_and_greet for an enrollment application
      if params[:event][:event_type] == 'meet_and_greet' &&
         params[:event][:eventable_type] == 'EnrollmentApplication'

        application = EnrollmentApplication.find(params[:event][:eventable_id])
        service = EnrollmentWorkflowService.new(application)

        event = service.schedule_meeting(
          location_id: params[:event][:location_id],
          scheduled_at: params[:event][:scheduled_at],
          notes: params[:event][:notes]
        )

        render json: event, status: :created
      else
        # Generic event creation
        event = Event.new(event_params)

        if event.save
          render json: event, status: :created
        else
          render json: { errors: event.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end

    def update
      event = Event.find(params[:id])
      event.update!(event_params)
      render json: event
    end

    def complete
      event = Event.find(params[:id])

      # If it's a meet_and_greet, use the workflow service
      if event.event_type == 'meet_and_greet' && event.eventable_type == 'EnrollmentApplication'
        service = EnrollmentWorkflowService.new(event.eventable)
        service.complete_meeting(event.id, outcome_notes: params[:outcome_notes])
      else
        event.complete!(params[:outcome_notes])
      end

      render json: event.reload
    end

    def cancel
      event = Event.find(params[:id])
      event.cancel!(params[:reason])
      render json: event
    end

    def confirm
      event = Event.find(params[:id])
      event.confirm!
      render json: event
    end

    private

    def event_params
      params.require(:event).permit(
        :eventable_type, :eventable_id, :location_id,
        :event_type, :title, :description,
        :scheduled_at, :notes, :outcome_notes
      )
    end
  end
end
