FactoryBot.define do
  factory :webhook_event do
    provider { 'revenuecat' }
    sequence(:external_event_id) { |n| "evt_#{n}" }
    event_type { 'INITIAL_PURCHASE' }
    received_at { Time.current }
    status { 'pending' }
    payload { { event: { id: external_event_id, type: event_type } } }

    trait :processed do
      status { 'processed' }
      processed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      error_message { 'something went wrong' }
    end

    trait :skipped do
      status { 'skipped' }
    end
  end
end
