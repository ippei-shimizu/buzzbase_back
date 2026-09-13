require 'rails_helper'

RSpec.describe Entitlement, type: :model do
  let(:user) { create(:user) }

  describe 'feature key constants' do
    it 'defines exactly 11 free features and 32 pro features' do
      # %w[] とインラインコメントの混在で feature key が壊れる回帰を防ぐ
      expect(described_class::FREE_FEATURES.size).to eq 11
      expect(described_class::PRO_FEATURES.size).to eq 32
      expect(described_class::ALL_FEATURES.size).to eq 43
    end

    it 'contains only valid feature key strings (no stray symbols)' do
      described_class::ALL_FEATURES.each do |key|
        expect(key).to match(/\A[a-z][a-z0-9_]+\z/), "Invalid feature key: #{key.inspect}"
      end
    end
  end

  describe '#has_entitlement?' do
    context 'with a free feature' do
      it 'returns true for a free user' do
        expect(user.has_entitlement?('basic_game_record')).to be true
      end

      it 'returns true for a Pro user' do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
        expect(user.has_entitlement?('basic_game_record')).to be true
      end
    end

    context 'with a Pro feature' do
      it 'returns false for a free user' do
        expect(user.has_entitlement?('season_transition_graph')).to be false
      end

      it 'returns true for a user with active Pro subscription' do
        user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
        expect(user.has_entitlement?('season_transition_graph')).to be true
      end

      it 'returns true for a user in trial' do
        user.subscription.update!(status: 'trial', expires_at: 7.days.from_now)
        expect(user.has_entitlement?('season_transition_graph')).to be true
      end

      it 'returns true for a user in grace period (cancelled within expiration)' do
        user.subscription.update!(status: 'cancelled', expires_at: 3.days.from_now)
        expect(user.has_entitlement?('season_transition_graph')).to be true
      end

      it 'returns false for a user whose subscription has expired' do
        user.subscription.update!(status: 'expired', expires_at: 1.day.ago)
        expect(user.has_entitlement?('season_transition_graph')).to be false
      end
    end

    context 'with an unknown feature key' do
      it 'raises ArgumentError' do
        expect { user.has_entitlement?('unknown_feature') }.to raise_error(ArgumentError, /Unknown feature/)
      end
    end
  end

  describe '#can_create_practice_menu?' do
    it 'returns true for a Pro user (unlimited)' do
      user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      expect(user.can_create_practice_menu?).to be true
    end

    it 'returns true for a free user when below limit' do
      expect(user.can_create_practice_menu?).to be true
    end
  end

  describe '#can_create_season_goal?' do
    it 'returns false for a free user' do
      expect(user.can_create_season_goal?).to be false
    end

    it 'returns true for a Pro user' do
      user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      expect(user.can_create_season_goal?).to be true
    end
  end

  describe '#can_create_or_join_group?' do
    it 'returns true for a free user with no groups' do
      expect(user.can_create_or_join_group?).to be true
    end

    it 'returns false for a free user already belonging to 1 group' do
      GroupInvitation.create!(user:, group: create(:group), state: 'accepted', sent_at: Time.current)
      expect(user.can_create_or_join_group?).to be false
    end

    it 'returns true for a Pro user regardless of existing groups' do
      user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      2.times { GroupInvitation.create!(user:, group: create(:group), state: 'accepted', sent_at: Time.current) }
      expect(user.can_create_or_join_group?).to be true
    end

    it 'does not modify existing accepted group invitations (grandfathering)' do
      2.times { GroupInvitation.create!(user:, group: create(:group), state: 'accepted', sent_at: Time.current) }
      expect { user.can_create_or_join_group? }.not_to(change { user.group_invitations.accepted.count })
      expect(user.group_invitations.accepted.count).to eq 2
    end
  end

  describe '#can_upload_media_this_month?' do
    let(:note) { create(:baseball_note, user:) }

    it 'returns true for a free user below the monthly limit' do
      create_list(:media_attachment, 2, :ready, user:, baseball_note: note)
      expect(user.can_upload_media_this_month?).to be true
    end

    it 'returns false for a free user who reached the monthly limit' do
      create_list(:media_attachment, 3, :ready, user:, baseball_note: note)
      expect(user.can_upload_media_this_month?).to be false
    end

    it 'excludes failed attachments from the monthly count' do
      create_list(:media_attachment, 3, :ready, status: 'failed', user:, baseball_note: note)
      expect(user.can_upload_media_this_month?).to be true
    end

    it 'excludes attachments created in a previous month' do
      travel_to(1.month.ago) { create_list(:media_attachment, 3, :ready, user:, baseball_note: note) }
      expect(user.can_upload_media_this_month?).to be true
    end

    it 'returns true for a Pro user beyond the monthly limit' do
      user.subscription.update!(status: 'active', expires_at: 30.days.from_now)
      create_list(:media_attachment, 3, :ready, user:, baseball_note: note)
      expect(user.can_upload_media_this_month?).to be true
    end

    it 'excludes pending attachments older than the stale threshold' do
      travel_to(2.hours.ago) { create_list(:media_attachment, 3, user:, baseball_note: note) }
      expect(user.can_upload_media_this_month?).to be true
    end

    it 'counts pending attachments still within the stale threshold' do
      create_list(:media_attachment, 3, user:, baseball_note: note)
      expect(user.can_upload_media_this_month?).to be false
    end
  end
end
