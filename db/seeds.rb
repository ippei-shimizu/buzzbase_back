# 開発環境データの作成はrakeタスクを使用してください
#
#   rake dev_data:setup   -- マスターデータ + サンプルデータを一括作成
#   rake dev_data:master  -- マスターデータのみ（Position, Prefecture, BaseballCategory, Admin::User）
#   rake dev_data:sample  -- サンプルデータのみ（マスターデータが必要）
#   rake dev_data:reset   -- DB再作成 + setup（db:drop → db:create → db:migrate → dev_data:setup）
#
# 詳細: lib/tasks/dev_data.rake

Rails.logger.debug 'db:seed は無効です。代わりに `rake dev_data:setup` を使用してください。'
