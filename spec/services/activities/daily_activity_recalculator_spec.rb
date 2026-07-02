require 'rails_helper'

RSpec.describe Activities::DailyActivityRecalculator do
  let(:user) { create(:user) }
  let(:today) { Time.find_zone('Asia/Tokyo').today }

  def recalc
    described_class.new(user_id: user.id, date: today).call
  end

  describe '#call' do
    context '練習も試合も無い日' do
      it 'activity_log を作らず nil を返す' do
        expect(recalc).to be_nil
        expect(ActivityLog.where(user:, activity_date: today)).to be_empty
      end
    end

    context '1メニューだけ記録した日' do
      before { create(:practice_log, user:, logged_on: today) }

      it 'intensity_level 1 で作られる' do
        log = recalc
        expect(log.practice_menu_count).to eq(1)
        expect(log.intensity_level).to eq(1)
      end
    end

    context '2種のメニューを記録した日' do
      before do
        menu_a = create(:practice_menu, user:)
        menu_b = create(:practice_menu, user:)
        create(:practice_log, user:, practice_menu: menu_a, logged_on: today)
        create(:practice_log, user:, practice_menu: menu_b, logged_on: today)
      end

      it 'intensity_level 2' do
        expect(recalc.intensity_level).to eq(2)
      end
    end

    context '同じメニューを2回記録した日' do
      before do
        menu = create(:practice_menu, user:)
        create(:practice_log, user:, practice_menu: menu, logged_on: today)
        create(:practice_log, user:, practice_menu: menu, logged_on: today)
      end

      it 'distinct メニュー数は1なので intensity_level 1' do
        expect(recalc.practice_menu_count).to eq(1)
        expect(recalc.intensity_level).to eq(1)
      end
    end

    context '素振り300本を記録した日' do
      before { create(:practice_log, :shadow_swing, user:, logged_on: today, amount: 300) }

      it 'total_swing_count 300 / intensity_level 3' do
        log = recalc
        expect(log.total_swing_count).to eq(300)
        expect(log.intensity_level).to eq(3)
      end
    end

    context '試合がある日' do
      before { create(:game_result, user:) }

      it 'has_game true / intensity_level 4' do
        log = recalc
        expect(log.has_game).to be(true)
        expect(log.intensity_level).to eq(4)
      end
    end

    context 'コンディションのみ記録した日' do
      before { create(:condition_log, user:, logged_on: today) }

      it '草に影響しない（activity_log は作られない）' do
        expect(recalc).to be_nil
      end
    end

    context '一度作った後に活動が無くなった日' do
      before { create(:activity_log, user:, activity_date: today, intensity_level: 2) }

      it '再計算で activity_log が削除される' do
        expect(recalc).to be_nil
        expect(ActivityLog.where(user:, activity_date: today)).to be_empty
      end
    end
  end
end
