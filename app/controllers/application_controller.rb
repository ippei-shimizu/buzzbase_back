class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken
  include DeviseHackFakeSession

  before_action do
    I18n.locale = :ja
  end
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_sentry_context
  after_action :update_last_login_at, if: :user_signed_in?

  rescue_from StandardError do |exception|
    Sentry.capture_exception(exception) if defined?(Sentry)
    render json: { errors: ['内部サーバーエラーが発生しました'] }, status: :internal_server_error
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name user_id])
  end

  private

  def update_last_login_at
    return unless current_user
    return if current_user.last_login_at&.> 1.hour.ago

    current_user.update!(last_login_at: Time.current)
  end

  def set_sentry_context
    return unless defined?(Sentry)

    Sentry.set_user(id: current_user.id) if current_user
    Sentry.set_extras(
      request_id: request.request_id,
      user_agent: request.user_agent
    )
  end
end
