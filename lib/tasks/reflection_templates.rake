# 振り返りテンプレのプリセット関連タスク。
# - reflection_templates:seed_presets — 運営プリセットを冪等に再投入する
# - reflection_templates:status       — 現在のプリセット件数と内容を出力する

namespace :reflection_templates do
  desc '運営プリセット（ReflectionTemplate::PRESETS）を冪等に投入する'
  task seed_presets: :environment do
    count = ReflectionTemplate.seed_presets!
    puts "Seeded #{count} reflection template presets (total presets: #{ReflectionTemplate.presets.count})"
  end

  desc 'プリセットの現在の投入状況を出力する'
  task status: :environment do
    presets = ReflectionTemplate.presets.ordered
    puts "presets: #{presets.count} / expected: #{ReflectionTemplate::PRESETS.size}"
    presets.each { |template| puts "  - #{template.title}: #{template.questions.join(' / ')}" }
  end
end
