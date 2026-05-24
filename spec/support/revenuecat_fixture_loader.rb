module RevenueCatFixtureLoader
  FIXTURE_ROOT = Rails.root.join('spec/fixtures/revenuecat').freeze

  def load_revenuecat_fixture(name)
    JSON.parse(FIXTURE_ROOT.join("#{name}.json").read)
  end
end

RSpec.configure do |config|
  config.include RevenueCatFixtureLoader
end
