class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken
  include DeviseHackFakeSession

  before_action do
    I18n.locale = :ja
  end
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :update_last_login_at, if: :user_signed_in?

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name user_id])
  end

  private

  def update_last_login_at
    return unless current_user
    return if current_user.last_login_at&.> 1.hour.ago

    current_user.update!(last_login_at: Time.current)
  end
end
