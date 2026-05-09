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
    Rails.logger.error("#{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace&.first(10)&.join("\n"))
    Sentry.capture_exception(exception) if Sentry.initialized?
    render json: { errors: ['内部サーバーエラーが発生しました'] }, status: :internal_server_error unless performed?
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render json: { errors: [exception.message] }, status: :bad_request
  end

  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: ['リソースが見つかりません'] }, status: :not_found unless performed?
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    if Sentry.initialized?
      Sentry.capture_message(
        "Validation failed: #{exception.record.class.name}",
        level: :info,
        extra: {
          errors: exception.record.errors.full_messages,
          record_class: exception.record.class.name
        }
      )
    end
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  # ActiveRecord 層のバリデーションをすり抜けた外部キー違反 (例: 並列削除によるレース、
  # 新たに追加されたカラムでバリデーション漏れ等) は 500 ではなく 422 として扱い、
  # ユーザーに「不正な入力」であることが伝わる形で返す。後続調査用に Sentry にも記録。
  rescue_from ActiveRecord::InvalidForeignKey do |exception|
    Rails.logger.warn("InvalidForeignKey: #{exception.message}")
    Sentry.capture_exception(exception) if Sentry.initialized?
    render json: { errors: ['指定された関連データが存在しません'] }, status: :unprocessable_entity
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name user_id])
  end

  private

  def update_last_login_at
    return unless current_user&.persisted?
    return if current_user.last_login_at&.> 1.hour.ago

    current_user.update_column(:last_login_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def set_sentry_context
    return unless Sentry.initialized?

    Sentry.set_user(id: current_user.id) if current_user
    Sentry.set_extras(
      request_id: request.request_id,
      user_agent: request.user_agent
    )
    Sentry.set_tags(
      api_version: request.path.match(%r{/api/(v\d+)/})&.captures&.first || 'unknown',
      user_type: current_user ? 'user' : 'guest'
    )
  end
end
