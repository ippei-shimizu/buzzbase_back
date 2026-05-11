namespace :data do
  # match_results.match_type に日本語値「練習試合」で保存されたレコードを
  # 英語キー "open"（オープン戦）に正規化する一度きりのデータ修正タスク。
  #
  # 「練習試合」は非公式戦（オープン戦）と同義のため "open" に集約する。
  # 過去フォームや開発用シード由来で混入したレコードを救済する目的。
  #
  # 実行例:
  #   docker compose exec back bundle exec rails data:normalize_match_type DRY_RUN=1
  #   docker compose exec back bundle exec rails data:normalize_match_type
  #   heroku run bundle exec rails data:normalize_match_type
  desc 'match_type の日本語値「練習試合」を "open" に正規化する'
  task normalize_match_type: :environment do
    target = MatchResult.where(match_type: '練習試合')
    count = target.count
    puts "対象レコード数: #{count}"

    if count.zero?
      puts '更新対象がないため終了します。'
      next
    end

    if ENV['DRY_RUN'].present?
      puts 'DRY_RUN=1 が指定されたため、更新はスキップしました。'
      next
    end

    updated = target.update_all(match_type: 'open')
    puts "更新完了: #{updated}件"
  end
end
