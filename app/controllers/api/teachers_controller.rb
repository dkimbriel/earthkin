# frozen_string_literal: true

module Api
  class TeachersController < BaseController
    def index
      teachers = Teacher.includes(:user, :programs).order(:last_name, :first_name)
      render json: teachers.map { |t| teacher_json(t) }
    end

    def show
      teacher = Teacher.includes(:user, :programs, :program_classes).find(params[:id])
      render json: teacher_json(teacher, include_details: true)
    end

    def create
      teacher = Teacher.new(teacher_params)
      attach_avatar(teacher) if params[:teacher][:avatar].present?
      teacher.save!
      render json: teacher_json(teacher), status: :created
    end

    def update
      teacher = Teacher.find(params[:id])
      teacher.assign_attributes(teacher_params)
      attach_avatar(teacher) if params[:teacher][:avatar].present?
      teacher.save!
      render json: teacher_json(teacher, include_details: true)
    end

    def destroy
      teacher = Teacher.find(params[:id])
      teacher.destroy!
      head :no_content
    end

    private

    def teacher_params
      params.require(:teacher).permit(:first_name, :last_name, :email, :phone, :bio, :user_id)
    end

    def attach_avatar(teacher)
      avatar_data = params[:teacher][:avatar]
      if avatar_data.is_a?(ActionDispatch::Http::UploadedFile)
        teacher.avatar.attach(avatar_data)
      elsif avatar_data.is_a?(String) && avatar_data.start_with?('data:')
        # Handle base64 encoded image
        decoded = decode_base64_image(avatar_data)
        teacher.avatar.attach(decoded) if decoded
      end
    end

    def decode_base64_image(data_uri)
      return nil unless data_uri.present?

      mime_type, encoded_data = data_uri.match(/data:(.*?);base64,(.*)/)&.captures
      return nil unless mime_type && encoded_data

      extension = mime_type.split('/').last
      filename = "avatar_#{SecureRandom.hex(8)}.#{extension}"

      {
        io: StringIO.new(Base64.decode64(encoded_data)),
        filename: filename,
        content_type: mime_type
      }
    end

    def teacher_json(teacher, include_details: false)
      json = teacher.as_json(only: %i[id first_name last_name email phone bio user_id created_at updated_at])
      json['full_name'] = teacher.full_name
      json['avatar_url'] = teacher.avatar_url
      json['programs'] = teacher.programs.as_json(only: %i[id name]) if include_details
      json['program_classes'] = teacher.program_classes.as_json(only: %i[id name date]) if include_details
      json
    end
  end
end
