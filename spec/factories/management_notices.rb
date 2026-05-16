FactoryBot.define do
  factory :management_notice do
    sequence(:title) { |n| "お知らせ#{n}" }
    body { 'お知らせ本文' }
    status { :draft }
    notified_at { nil }
    created_by { association :admin_user }

    # 通常の :published は「すでに通知送信済み」状態を表す。
    # after_commitによるプッシュ通知ジョブの意図しないenqueueを避けるため notified_at をデフォルトで設定する。
    # 通知ジョブのenqueue自体をテストしたい場合は notified_at: nil を明示的に渡すこと。
    trait :published do
      status { :published }
      notified_at { Time.current }
    end
  end
end
