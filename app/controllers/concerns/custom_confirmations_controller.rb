class CustomConfirmationsController < DeviseTokenAuth::ConfirmationsController
  def show
    super do |resource|
      if resource.errors.empty?
        redirect_url = your_custom_path(resource)
        render json: { message: 'Confirmation successful.', redirect_url: redirect_url }, status: :ok
      else
        render json: { message: resource.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end
  end

  private

  def your_custom_path(resource)
    token = params[:confirmation_token]
    "#{ENV.fetch('CONFIRM_SUCCESS_URL', nil)}?confirmation_token=#{token}"
  end
end
