FactoryBot.define do
  factory :media_attachment do
    user
    baseball_note { association :baseball_note, user: }
    media_type { 'image' }
    sequence(:r2_key) { |n| "#{user.id}/#{baseball_note.id}/test-#{n}.jpg" }
    status { 'pending' }

    trait :video do
      media_type { 'video' }
      sequence(:r2_key) { |n| "#{user.id}/#{baseball_note.id}/test-#{n}.mp4" }
      sequence(:thumbnail_r2_key) { |n| "#{user.id}/#{baseball_note.id}/test-#{n}_thumb.jpg" }
    end

    trait :ready do
      status { 'ready' }
      file_size_bytes { 1_000_000 }
      duration_seconds { 10 }
      width { 720 }
      height { 480 }
    end
  end
end
