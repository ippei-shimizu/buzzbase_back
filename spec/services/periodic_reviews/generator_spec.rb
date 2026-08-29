require 'rails_helper'

RSpec.describe PeriodicReviews::Generator, type: :service do
  let(:user) { create(:user) }
  let(:period_start) { Time.find_zone('Asia/Tokyo').today.beginning_of_week - 7 }

  describe '#call（週次）' do
    before do
      create(:activity_log, user:, activity_date: period_start, total_swing_count: 300, intensity_level: 2)
      create(:activity_log, user:, activity_date: period_start + 1, total_swing_count: 200, intensity_level: 1)
    end

    it '基本部（練習量・Streak）と詳細部を集計して保存する' do
      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      expect(review).to be_persisted
      expect(review.period_end).to eq(period_start + 6)
      expect(review.summary['practice_days']).to eq(2)
      expect(review.summary['total_swings']).to eq(500)
      expect(review.summary).to have_key('theme_breakdown')
      expect(review.summary).to have_key('batting')
    end

    it '同一期間の再生成は upsert（重複を作らない）' do
      described_class.new(user:, period_type: 'weekly', period_start:).call
      expect do
        described_class.new(user:, period_type: 'weekly', period_start:).call
      end.not_to(change { user.periodic_reviews.count })
    end

    it '取組中の課題を内訳に含める' do
      theme = create(:improvement_theme, user:, status: 'open')
      create(:practice_session, user:, logged_on: period_start, improvement_theme: theme)
      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      breakdown = review.summary['theme_breakdown']
      expect(breakdown.first).to include('title' => theme.title, 'practice_count' => 1)
    end

    it '防御率は試合ごとの inning_format（7回制）で加重し、9固定より低く算出する' do
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: period_start.in_time_zone('Asia/Tokyo').noon, inning_format: 7)
      create(:pitching_result, user:, game_result:, innings_pitched: 7.0, earned_run: 7, base_on_balls: 0,
                               hits_allowed: 0, strikeouts: 7)

      review = described_class.new(user:, period_type: 'weekly', period_start:).call

      # 9固定なら (7*9/7)=9.00 になるところ、7回制加重で (7*7/7)=7.00 になる。
      expect(review.summary['pitching']['era']).to eq(7.0)
      expect(review.summary['pitching']['k_per_9']).to eq(7.0)
    end

    it '打撃の実数カウント（安打・二塁打・本塁打・盗塁・三振）を期間集計する' do
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: period_start.in_time_zone('Asia/Tokyo').noon)
      create(:batting_average, user:, game_result:, at_bats: 4, hit: 1, two_base_hit: 1, three_base_hit: 0,
                               home_run: 1, stealing_base: 2, strike_out: 1, total_bases: 7)

      batting = described_class.new(user:, period_type: 'weekly', period_start:).call.summary['batting']

      aggregate_failures do
        # 安打は NPB 標準（単打+二塁打+三塁打+本塁打）。単打のみの hit 列と混同しない。
        expect(batting['hits']).to eq(3)
        expect(batting['two_base_hits']).to eq(1)
        expect(batting['three_base_hits']).to eq(0)
        expect(batting['home_runs']).to eq(1)
        expect(batting['stolen_bases']).to eq(2)
        expect(batting['strikeouts']).to eq(1)
      end
    end

    it '得点圏は新フォーマット打席が無ければ打率 nil（母数 0）で保存する' do
      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      scoring = review.summary['batting']['scoring_position']

      aggregate_failures do
        expect(scoring['at_bats']).to eq(0)
        expect(scoring['batting_average']).to be_nil
      end
    end

    it '得点圏打席を日レンジで集計する（期間外は含めない）' do
      in_game = create(:game_result, user:)
      in_game.match_result.update!(date_and_time: period_start.in_time_zone('Asia/Tokyo').noon)
      create(:plate_appearance, user:, game_result: in_game, plate_result_id: 7,
                                runners_state: :second, is_new_format: true)
      out_game = create(:game_result, user:)
      out_game.match_result.update!(date_and_time: (period_start - 8).in_time_zone('Asia/Tokyo').noon)
      create(:plate_appearance, user:, game_result: out_game, plate_result_id: 13,
                                runners_state: :third, is_new_format: true)

      scoring = described_class.new(user:, period_type: 'weekly', period_start:)
                               .call.summary['batting']['scoring_position']

      aggregate_failures do
        expect(scoring['at_bats']).to eq(1)
        expect(scoring['hits']).to eq(1)
        expect(scoring['batting_average']).to eq(1.0)
      end
    end

    it '投手の登板数と実数カウント（奪三振・自責点など）は inning_format で加重しない' do
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: period_start.in_time_zone('Asia/Tokyo').noon, inning_format: 7)
      create(:pitching_result, user:, game_result:, innings_pitched: 7.0, earned_run: 3, run_allowed: 4,
                               base_on_balls: 2, hit_by_pitch: 1, hits_allowed: 5, home_runs_hit: 1, strikeouts: 8)

      pitching = described_class.new(user:, period_type: 'weekly', period_start:).call.summary['pitching']

      aggregate_failures do
        expect(pitching['appearances']).to eq(1)
        expect(pitching['strikeouts']).to eq(8)
        expect(pitching['earned_runs']).to eq(3)
        expect(pitching['runs_allowed']).to eq(4)
        expect(pitching['base_on_balls']).to eq(2)
        expect(pitching['hit_by_pitch']).to eq(1)
        expect(pitching['hits_allowed']).to eq(5)
        expect(pitching['home_runs_allowed']).to eq(1)
      end
    end

    it '練習メニュー別内訳は名前で名寄せし、上限を超えた分は other_count に丸める' do
      menus = Array.new(6) { |i| "メニュー#{i}" }
      menus.each_with_index do |name, i|
        (i + 1).times do |d|
          create(:practice_log, user:, practice_menu: nil, menu_name: name, unit_label: '本',
                                amount: 100, logged_on: period_start + (d % 7))
        end
      end

      breakdown = described_class.new(user:, period_type: 'weekly', period_start:)
                                 .call.summary['practice_menus']

      aggregate_failures do
        expect(breakdown['items'].size).to eq(5)
        expect(breakdown['items'].first).to include('name' => 'メニュー5', 'count' => 6, 'unit_label' => '本')
        expect(breakdown['other_count']).to eq(1)
      end
    end

    it 'ノート記録日数は同日の複数ノートを1日として数える' do
      create(:baseball_note, user:, date: period_start)
      create(:baseball_note, user:, date: period_start)
      create(:baseball_note, user:, date: period_start + 1)
      create(:baseball_note, user:, date: period_start - 1)

      review = described_class.new(user:, period_type: 'weekly', period_start:).call
      expect(review.summary['note_days']).to eq(2)
    end

    it '期間に重なる進行中の目標を締切の近い順に上限件数まで載せる' do
      overlapping = Array.new(4) do |i|
        create(:goal, user:, title: "目標#{i}", month_start: period_start - 10, deadline: period_start + 10 + i,
                      period_type: 'custom', metric_key: 'practice_days', target_value: 10)
      end
      # 期間より前に締切が過ぎた目標は載せない
      create(:goal, user:, month_start: period_start - 30, deadline: period_start - 1,
                    period_type: 'custom', metric_key: 'practice_days', target_value: 10)

      goals = described_class.new(user:, period_type: 'weekly', period_start:).call.summary['goals']

      aggregate_failures do
        expect(goals.size).to eq(3)
        expect(goals.pluck('title')).to eq(%w[目標0 目標1 目標2])
        expect(goals.first).to include('kind' => 'numeric', 'metric_key' => 'practice_days', 'achieved' => false)
        expect(goals.first.keys).to include('current_value', 'target_value', 'progress_percent', 'deadline')
        expect(overlapping.first.deadline.strftime('%Y-%m-%d')).to eq(goals.first['deadline'])
      end
    end

    it 'コンディションは睡眠・疲労に加えて体調（physical_level）の平均も保存する' do
      create(:condition_log, user:, logged_on: period_start, sleep_hours: 7.0, fatigue_level: 2, physical_level: 4)
      create(:condition_log, user:, logged_on: period_start + 1, sleep_hours: 8.0, fatigue_level: 3, physical_level: 3)

      condition = described_class.new(user:, period_type: 'weekly', period_start:).call.summary['condition']

      aggregate_failures do
        expect(condition['sleep_hours_avg']).to eq(7.5)
        expect(condition['fatigue_level_avg']).to eq(2.5)
        expect(condition['physical_level_avg']).to eq(3.5)
      end
    end
  end

  describe '#call（月次）' do
    it '月初〜月末を期間として保存する' do
      month_start = Time.find_zone('Asia/Tokyo').today.prev_month.beginning_of_month
      review = described_class.new(user:, period_type: 'monthly', period_start: month_start).call
      expect(review.period_type).to eq('monthly')
      expect(review.period_end).to eq(month_start.end_of_month)
    end

    it '成績の前期間比較は固定日数ではなく前月の暦月（1日を含む）で行う' do
      # 4月（30日）の固定日数方式だと 3/2〜3/31 になり 3/1 の試合が漏れる。
      game_result = create(:game_result, user:)
      game_result.match_result.update!(date_and_time: Time.find_zone('Asia/Tokyo').local(2026, 3, 1, 13, 0))
      create(:batting_average, user:, game_result:, hit: 1, at_bats: 3)

      review = described_class.new(user:, period_type: 'monthly', period_start: Date.new(2026, 4, 1)).call
      expect(review.summary['batting']['previous_batting_average']).to eq(0.333)
    end
  end
end
