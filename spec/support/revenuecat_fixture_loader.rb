module RevenueCatFixtureLoader
  FIXTURE_ROOT = Rails.root.join('spec/fixtures/revenuecat').freeze

  def load_revenuecat_fixture(name)
    JSON.parse(FIXTURE_ROOT.join("#{name}.json").read)
  end

  # fixture を読み込み、app_user_id を指定 user の id 文字列で上書きする。
  # 任意の event フィールドを overrides で部分書き換えできる（例: expires_at_ms / event_timestamp_ms）。
  def revenuecat_payload_for(name, user:, **overrides)
    data = load_revenuecat_fixture(name)
    data['event']['app_user_id'] = user.id.to_s
    data['event'].merge!(overrides.transform_keys(&:to_s))
    data
  end
end

RSpec.configure do |config|
  config.include RevenueCatFixtureLoader
end
