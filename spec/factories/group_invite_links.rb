FactoryBot.define do
  factory :group_invite_link do
    group
    inviter { association :user }
  end
end
