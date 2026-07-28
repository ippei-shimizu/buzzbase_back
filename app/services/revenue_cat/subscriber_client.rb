require 'net/http'
require 'uri'
require 'json'

module RevenueCat
  # RevenueCat REST API (GET /v1/subscribers/{app_user_id}) を叩く薄いクライアント。
  # サーバーサイド専用の secret key を使う(mobile側のSDK公開keyとは別物)。
  class SubscriberClient
    BASE_URL = 'https://api.revenuecat.com/v1'.freeze
    TIMEOUT_SECONDS = 5

    class RequestFailedError < StandardError; end

    # @param app_user_id [String] RevenueCatのapp_user_id(このアプリではuser.id.to_sを使う)
    # @return [Hash] `subscriber` 配下のHash
    def self.fetch_subscriber(app_user_id)
      new.fetch_subscriber(app_user_id)
    end

    def fetch_subscriber(app_user_id)
      uri = URI("#{BASE_URL}/subscribers/#{app_user_id}")
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{secret_key}"
      request['Content-Type'] = 'application/json'

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: TIMEOUT_SECONDS) do |http|
        http.request(request)
      end

      raise RequestFailedError, "RevenueCat API returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)['subscriber'] || {}
    end

    private

    def secret_key
      ENV.fetch('REVENUECAT_SECRET_API_KEY')
    end
  end
end
