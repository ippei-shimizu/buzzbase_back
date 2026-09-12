require 'carrierwave/storage/abstract'
require 'carrierwave/storage/file'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  # 既定の cache_dir は CarrierWave.root（= public/）配下のため、RAILS_SERVE_STATIC_FILES が
  # 有効だとリサイズ前の原本が静的配信されうる。public の外に逃がす。
  config.cache_dir = Rails.root.join('tmp/uploads').to_s

  if Rails.env.production?
    config.fog_provider = 'fog/aws'
    config.fog_credentials = {
      provider: 'AWS',
      aws_access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID', nil),
      aws_secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY', nil),
      region: 'ap-northeast-1'
    }
    config.fog_directory = ENV.fetch('AWS_BUCKET_NAME', nil)
    # cache も :fog にすると 1 回のアップロードで cache / store の 2 往復が S3 に発生する。
    # cache → store は同一リクエスト内（同一プロセス）で完結するため、cache はローカルの
    # ephemeral filesystem で十分。S3 への転送を store の 1 往復に減らす。
    config.cache_storage = :file
  else
    config.storage = :file
  end
end
