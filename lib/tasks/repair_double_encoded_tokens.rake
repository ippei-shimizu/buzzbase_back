namespace :data do
  # devise_token_auth 1.2.6 + Rails 7.1 アップグレード (PR #221) 後、json 型カラムである
  # `users.tokens` に対して devise_token_auth 側が `serialize :tokens, coder: TokensSerialization`
  # を当てたためダブルエンコードが発生し、`"...JSON文字列..."` のように JSON 文字列を
  # さらに文字列としてラップした値が DB に書き込まれた (Issue #340)。
  # 本タスクは `user.tokens` が String を返すレコード（健全な状態なら Hash が返る）を
  # JSON.parse して Hash に戻し、json カラムに直接書き戻す一度きりの修復タスク。
  # User モデル側で `attribute :tokens, ActiveRecord::Type::Json.new` を当てた状態で
  # 実行すること（先に実行すると再度ダブルエンコードされる）。
  #
  # 実行例:
  #   docker compose exec back bundle exec rails data:repair_double_encoded_tokens DRY_RUN=1
  #   heroku run bundle exec rails data:repair_double_encoded_tokens
  desc 'devise_token_auth アップグレードで発生した tokens カラムのダブルエンコードを修復する'
  task repair_double_encoded_tokens: :environment do
    dry_run = ENV['DRY_RUN'].present?
    scanned = 0
    repaired = 0

    User.find_each(batch_size: 200) do |user|
      scanned += 1
      current = user.tokens
      next unless current.is_a?(String)

      parsed = begin
        JSON.parse(current)
      rescue JSON::ParserError => e
        Rails.logger.warn("[repair_double_encoded_tokens] user_id=#{user.id} skip: #{e.message}")
        next
      end
      next unless parsed.is_a?(Hash)

      repaired += 1
      next if dry_run

      # コールバック・updated_at に触れずに tokens のみを書き戻す
      user.update_columns(tokens: parsed) # rubocop:disable Rails/SkipsModelValidations
    end

    puts "対象 #{scanned} 件中 #{repaired} 件を#{dry_run ? '修復可能と判定' : '修復しました'}。"
  end
end
