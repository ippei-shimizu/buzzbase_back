# 署名URL生成はネットワークアクセスを伴わないため、実際のR2認証情報がなくてもテストで実行できる。
ENV['R2_ENDPOINT'] ||= 'https://test-account.r2.cloudflarestorage.com'
ENV['R2_ACCESS_KEY_ID'] ||= 'test-access-key-id'
ENV['R2_SECRET_ACCESS_KEY'] ||= 'test-secret-access-key'
ENV['R2_BUCKET_NAME'] ||= 'buzzbase-test'
ENV['R2_PUBLIC_BASE_URL'] ||= 'https://media.buzzbase.test'
