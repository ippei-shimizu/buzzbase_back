require 'rails_helper'

RSpec.describe Season, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:game_results).dependent(:nullify) }
    it { should have_many(:goals).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:season) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe 'name の正規化' do
    let(:user) { create(:user) }

    it '前後のスペースを取り除いて保存する' do
      expect(described_class.create!(user:, name: '  2026春  ').name).to eq('2026春')
    end

    it '全角スペースも取り除いて保存する' do
      expect(described_class.create!(user:, name: '　2026春　').name).to eq('2026春')
    end

    it '連続スペースを1つに詰める' do
      expect(described_class.create!(user:, name: '2026  春').name).to eq('2026 春')
    end
  end

  describe '.find_or_create_for!' do
    let(:user) { create(:user) }

    it '同名シーズンが無ければ作成する' do
      expect { described_class.find_or_create_for!(user, '2026春') }.to change(described_class, :count).by(1)
    end

    it '同名シーズンが既にあれば作成せず既存を返す' do
      existing = create(:season, user:, name: '2026春')

      aggregate_failures do
        expect { described_class.find_or_create_for!(user, '2026春') }.not_to change(described_class, :count)
        expect(described_class.find_or_create_for!(user, '2026春')).to eq(existing)
      end
    end

    it '前後の空白違いでも既存を返す' do
      existing = create(:season, user:, name: '2026春')

      expect(described_class.find_or_create_for!(user, '  2026春　')).to eq(existing)
    end

    it '他ユーザーの同名シーズンは引き当てず自分のシーズンを作る' do
      create(:season, user: create(:user), name: '2026春')

      created = described_class.find_or_create_for!(user, '2026春')
      expect(created.user).to eq(user)
    end

    it '大文字小文字が違う場合は別シーズンとして作成される' do
      create(:season, user:, name: 'Spring')

      expect { described_class.find_or_create_for!(user, 'spring') }.to change(described_class, :count).by(1)
    end

    it 'name が空なら RecordInvalid を投げる' do
      expect { described_class.find_or_create_for!(user, '  ') }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'name が上限超過なら RecordInvalid を投げる' do
      expect { described_class.find_or_create_for!(user, 'a' * 51) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'INSERT が一意制約に負けたとき' do
      it '勝者の既存レコードを返す' do
        winner = create(:season, user:, name: '2026春')
        seasons = user.seasons
        # SELECT の後・INSERT の前に勝者がコミットした敗者側を再現する。
        allow(seasons).to receive(:find_by).and_return(nil, winner)
        allow(seasons).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        allow(user).to receive(:seasons).and_return(seasons)

        expect(described_class.find_or_create_for!(user, '2026春')).to eq(winner)
      end

      it '勝者を引き直せない場合は例外をそのまま投げる' do
        seasons = user.seasons
        allow(seasons).to receive(:find_by).and_return(nil)
        allow(seasons).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        allow(user).to receive(:seasons).and_return(seasons)

        expect do
          described_class.find_or_create_for!(user, '2026春')
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe '#destroy' do
    let(:user) { create(:user) }
    let(:season) { create(:season, user:) }

    def season_goal(user:, season:, is_finalized:)
      create(:goal, user:, season:, period_type: 'season', month_start: nil, is_finalized:)
    end

    it '進行中のシーズン目標が紐づいている場合は削除できない' do
      season_goal(user:, season:, is_finalized: false)

      aggregate_failures do
        expect(season.destroy).to be false
        expect(season.errors.full_messages).to include('進行中のシーズン目標が紐づいているため削除できません')
        expect(described_class.exists?(season.id)).to be true
      end
    end

    it '確定済みのシーズン目標だけなら削除でき、目標の紐付けは外れる' do
      goal = season_goal(user:, season:, is_finalized: true)

      aggregate_failures do
        expect(season.destroy).to be_truthy
        expect(goal.reload.season_id).to be_nil
      end
    end

    it 'シーズン目標が紐づいていなければ削除できる' do
      expect(season.destroy).to be_truthy
    end
  end
end
