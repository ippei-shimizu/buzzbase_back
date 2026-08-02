class FinalizeGoalsJob < ApplicationJob
  queue_as :default

  # 期限到来済みの未確定目標を確定し、達成ならバッジを付与する（push はしない）。
  def perform
    today = Time.find_zone('Asia/Tokyo').today
    Goal.active.where(deadline: ...today).find_each do |goal|
      # ジョブの重複実行で二重確定・バッジ二重付与しないよう、行ロック後に確定済みを除外する。
      goal.with_lock do
        next if goal.is_finalized

        calculator = ::Goals::ProgressCalculator.new(goal)
        achieved = calculator.achieved?
        goal.update!(
          achieved_value: calculator.current_value,
          is_achieved: achieved,
          # 定性目標はユーザーが達成ボタンを押した時刻が既に入っているため、ジョブ実行時刻で上書きしない。
          achieved_at: achieved ? (goal.achieved_at || Time.current) : nil,
          is_finalized: true
        )
        award_badge(goal) if achieved
      end
    end
  end

  private

  def award_badge(goal)
    badge_type = "#{goal.period_type}_achieved"
    badge_name = BADGE_NAMES.fetch(goal.period_type, '目標達成')
    goal.goal_badges.create!(
      user: goal.user,
      badge_type:,
      badge_name:,
      # 目標が後から削除されてもバッジ一覧に何の目標だったか出せるようスナップショットする。
      goal_title: goal.title,
      awarded_at: Time.current
    )
  end

  BADGE_NAMES = {
    'season' => 'シーズン目標達成',
    'monthly' => '月間目標達成',
    'tournament' => '大会目標達成'
  }.freeze
end
