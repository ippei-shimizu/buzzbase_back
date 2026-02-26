require 'net/http'
require 'uri'
require 'json'

class SlackNotificationService
  TIMEOUT_SECONDS = 5

  class << self
    def notify_new_user(user)
      webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
      return if webhook_url.blank?

      payload = build_new_user_payload(user)
      post_to_slack(webhook_url, payload)
    rescue StandardError => e
      Rails.logger.error("[SlackNotification] Failed to send notification: #{e.message}")
      Sentry.capture_exception(e) if Sentry.initialized?
    end

    private

    def build_new_user_payload(user)
      {
        text: ':baseball: 新規ユーザー登録',
        blocks: [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: '新規ユーザーが登録されました'
            }
          },
          {
            type: 'section',
            fields: [
              { type: 'mrkdwn', text: "*ユーザー名:*\n#{user.name}" },
              { type: 'mrkdwn', text: "*ユーザーID:*\n#{user.user_id || '未設定'}" },
              { type: 'mrkdwn', text: "*メールアドレス:*\n#{user.email}" },
              { type: 'mrkdwn', text: "*登録方法:*\n#{user.provider}" },
              { type: 'mrkdwn', text: "*登録日時:*\n#{user.created_at.strftime('%Y/%m/%d %H:%M')}" }
            ]
          }
        ]
      }
    end

    def post_to_slack(webhook_url, payload)
      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)
      return if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("[SlackNotification] Unexpected response: #{response.code} #{response.body}")
    end
  end
end
