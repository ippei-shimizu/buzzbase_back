FactoryBot.define do
  factory :admin_user, class: 'Admin::User' do
    sequence(:email) { |n| "admin#{n}@example.com" }
    sequence(:name) { |n| "Admin User #{n}" }
    password { 'password' }
  end
end
