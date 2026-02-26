class Api::V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  private

  def sign_up_params
    params.require(:registration).permit(:email, :password, :password_confirmation, :name, :user_id, :confirm_success_url)
  end

  def render_create_success
    EmailAuthenticationMailer.send_when_signup(@resource.email, @resource.name).deliver_now
    SlackNotificationService.notify_new_user(@resource)
    super
  end
end
