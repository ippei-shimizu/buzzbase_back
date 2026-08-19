# 認証エンドポイントへのブルートフォース対策。IP 単位とメールアドレス単位の2軸で試行回数を制限する。
module AuthThrottle
  # 素の Devise ルート（config/routes.rb の devise_for）も API モードのまま公開されているため対象に含める。
  SIGN_IN_PATHS = ['/api/v1/auth/sign_in', '/users/sign_in'].freeze
  SIGN_UP_PATHS = ['/api/v1/auth', '/users'].freeze
  PASSWORD_RESET_PATHS = ['/api/v1/auth/password', '/users/password'].freeze
  TOKEN_LOOKUP_PATHS = [
    '/api/v1/auth/password/edit', '/api/v1/auth/confirmation',
    '/users/password/edit', '/users/confirmation'
  ].freeze
  CONFIRMATION_RESEND_PATHS = ['/api/v1/auth/confirmation', '/users/confirmation'].freeze
  OAUTH_PATHS = ['/api/v1/google_sign_in', '/api/v1/apple_sign_in'].freeze
  ADMIN_SIGN_IN_PATHS = ['/api/v1/admin/sign_in'].freeze

  # JSON ボディを読むサイズ上限。認証リクエストはこれを超えない。
  MAX_JSON_BODY_BYTES = 4096

  # Heroku ルーターは X-Forwarded-For の末尾に実クライアント IP を付与する。
  # Rack::Request#ip は REMOTE_ADDR を優先し Heroku 上ではルーターの IP を返しうるため、末尾を明示的に採用する。
  def self.client_ip(request)
    forwarded = request.get_header('HTTP_X_FORWARDED_FOR')
    forwarded.to_s.split(',').last&.strip.presence || request.ip
  end

  # front / mobile は Content-Type: application/json で送るが Rack::Request#params は
  # form-encoded しかパースしないため、JSON の場合はボディを自前で読む。
  # chunked 転送やサイズ上限超過で email が取れない場合は nil を返し、
  # そのリクエストは email 単位のスロットルの対象外になる（IP 単位は引き続き効く）。
  def self.auth_email(request)
    raw = json_body_email(request) || request.params['email']
    raw.to_s.downcase.strip.presence
  end

  def self.json_body_email(request)
    return nil unless request.content_type.to_s.include?('json')

    length = request.content_length.to_i
    return nil unless length.positive? && length <= MAX_JSON_BODY_BYTES

    body = request.body.read
    request.body.rewind
    parsed = JSON.parse(body)
    parsed.is_a?(Hash) ? parsed['email'] : nil
  rescue StandardError
    # ミドルウェア層のため、ここで例外を漏らすと Rails のエラーハンドリングを経ない生の 500 になる。
    nil
  end

  # Rails のルーターは `.json` 等のフォーマット拡張子付きでも同じアクションに解決するため、
  # 拡張子を落としてから比較しないとスロットルをすり抜けられる。
  # 末尾スラッシュは Rack::Attack が PATH_INFO を正規化済みなのでここでは扱わない。
  def self.match_path?(request, paths)
    paths.include?(request.path.sub(/\.\w+\z/, ''))
  end

  def self.post_to?(request, paths)
    request.post? && match_path?(request, paths)
  end
end

# Rails.cache は production が file_store（Heroku の ephemeral FS）、test が null_store のため使えない。
# dyno 単位のカウントで十分なので専用のメモリストアを割り当てる。
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new(size: 4.megabytes)

# 既存の認証リクエストスペックが sign_in を連投するため、test では既定で無効にし専用スペック内でのみ有効化する。
Rack::Attack.enabled = !Rails.env.test?

Rack::Attack.throttle('auth/sign_in/ip', limit: 30, period: 5.minutes) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::SIGN_IN_PATHS)
end

Rack::Attack.throttle('auth/sign_in/email', limit: 20, period: 20.minutes) do |request|
  AuthThrottle.auth_email(request) if AuthThrottle.post_to?(request, AuthThrottle::SIGN_IN_PATHS)
end

# 学校やチームの共有 Wi-Fi（NAT 配下の同一 IP）から複数人が続けて登録するケースがあるため
# IP 単位は余裕を持たせ、同一アドレスへの繰り返し登録試行は email 単位側で抑止する。
Rack::Attack.throttle('auth/sign_up/ip', limit: 15, period: 1.hour) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::SIGN_UP_PATHS)
end

Rack::Attack.throttle('auth/sign_up/email', limit: 3, period: 1.hour) do |request|
  AuthThrottle.auth_email(request) if AuthThrottle.post_to?(request, AuthThrottle::SIGN_UP_PATHS)
end

Rack::Attack.throttle('auth/password_reset/ip', limit: 5, period: 1.hour) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::PASSWORD_RESET_PATHS)
end

Rack::Attack.throttle('auth/password_reset/email', limit: 3, period: 1.hour) do |request|
  AuthThrottle.auth_email(request) if AuthThrottle.post_to?(request, AuthThrottle::PASSWORD_RESET_PATHS)
end

# 確認メールの再送はメール爆撃に使えるためリセット申請と同等に制限する。
Rack::Attack.throttle('auth/confirmation_resend/ip', limit: 5, period: 1.hour) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::CONFIRMATION_RESEND_PATHS)
end

Rack::Attack.throttle('auth/confirmation_resend/email', limit: 3, period: 1.hour) do |request|
  AuthThrottle.auth_email(request) if AuthThrottle.post_to?(request, AuthThrottle::CONFIRMATION_RESEND_PATHS)
end

# リセット・確認トークンの総当たりを防ぐ。
Rack::Attack.throttle('auth/token_lookup/ip', limit: 20, period: 1.hour) do |request|
  AuthThrottle.client_ip(request) if request.get? && AuthThrottle.match_path?(request, AuthThrottle::TOKEN_LOOKUP_PATHS)
end

Rack::Attack.throttle('auth/oauth/ip', limit: 20, period: 5.minutes) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::OAUTH_PATHS)
end

Rack::Attack.throttle('admin/sign_in/ip', limit: 5, period: 20.minutes) do |request|
  AuthThrottle.client_ip(request) if AuthThrottle.post_to?(request, AuthThrottle::ADMIN_SIGN_IN_PATHS)
end

Rack::Attack.throttle('admin/sign_in/email', limit: 5, period: 20.minutes) do |request|
  AuthThrottle.auth_email(request) if AuthThrottle.post_to?(request, AuthThrottle::ADMIN_SIGN_IN_PATHS)
end

# front / mobile は error を安定コードとして判定し message をそのまま表示する。
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data'] || {}
  period = match_data[:period].to_i
  retry_after = period.positive? ? period - (match_data[:epoch_time].to_i % period) : 60
  body = {
    error: 'rate_limit_exceeded',
    message: '試行回数が上限に達しました。しばらく時間をおいてからお試しください'
  }.to_json

  [429, { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s }, [body]]
end

# メールアドレスはログに残さない。
ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn(
    "[Rack::Attack] throttled name=#{request.env['rack.attack.matched']} " \
    "ip=#{AuthThrottle.client_ip(request)} path=#{request.path}"
  )
end
