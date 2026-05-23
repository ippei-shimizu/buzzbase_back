# Flipper の永続化に Active Record を使う設定。
# 既知フィーチャーをコードで宣言しておくことで、未登録キー参照時の typo を検知しやすくする。
Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

Rails.application.config.after_initialize do
  next unless Flipper::Adapters::ActiveRecord::Feature.table_exists?

  %i[pro_features cancellation_survey].each do |feature|
    Flipper.add(feature) unless Flipper.exist?(feature)
  end
rescue ActiveRecord::ActiveRecordError
  # マイグレーション前の初回 boot では feature を登録できないが無視する。
end
