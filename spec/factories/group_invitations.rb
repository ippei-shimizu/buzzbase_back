FactoryBot.define do
  factory :group_invitation do
    user
    group
    state { 'pending' }
    sent_at { Time.current }
  end
end
