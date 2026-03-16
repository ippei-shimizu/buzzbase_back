class Api::V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  def create
    super
  rescue ActiveRecord::RecordNotUnique
    render json: { status: 'error', errors: ['このメールアドレスは既に使用されています'] }, status: :unprocessable_entity
  end

  private

  def sign_up_params
    params.permit(:email, :password, :password_confirmation, :name, :user_id)
  end

  def render_create_success
    begin
      EmailAuthenticationMailer.send_when_signup(@resource).deliver_now
    rescue StandardError => e
      Rails.logger.error("Registration email failed: #{e.message}")
      Sentry.capture_exception(e) if Sentry.initialized?
    end

    render json: {
      status: 'success',
      data: resource_data
    }
  end

  def render_create_error
    return if performed?

    render json: {
      status: 'error',
      data: resource_data,
      errors: resource_errors
    }, status: :unprocessable_entity
  end
end
