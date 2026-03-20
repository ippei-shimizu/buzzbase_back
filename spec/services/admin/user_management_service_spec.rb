require 'rails_helper'

RSpec.describe Admin::UserManagementService do
  describe '#call' do
    let!(:user_a) { create(:user, name: 'Alice', created_at: 3.days.ago) }
    let!(:user_b) { create(:user, name: 'Bob', created_at: 2.days.ago) }
    let!(:user_c) { create(:user, name: 'Carol', created_at: 1.day.ago) }

    it 'returns all non-deleted users by default' do
      result = described_class.new.call

      expect(result[:users]).to include(user_a, user_b, user_c)
    end

    it 'returns pagination metadata' do
      result = described_class.new.call

      expect(result[:pagination]).to include(
        current_page: 1,
        per_page: Admin::UserManagementService::DEFAULT_PER_PAGE
      )
      expect(result[:pagination][:total_count]).to be >= 3
      expect(result[:pagination][:total_pages]).to be >= 1
    end

    context 'with search param' do
      it 'filters users by name' do
        result = described_class.new(search: 'Alice').call

        expect(result[:users]).to include(user_a)
        expect(result[:users]).not_to include(user_b, user_c)
      end

      it 'filters users by partial email match' do
        result = described_class.new(search: user_b.email.split('@').first).call

        expect(result[:users]).to include(user_b)
      end

      it 'returns all users when search is blank' do
        result = described_class.new(search: '').call

        expect(result[:users]).to include(user_a, user_b, user_c)
      end
    end

    context 'with status filter' do
      let!(:suspended_user) do
        u = create(:user)
        u.update!(suspended_at: Time.current)
        u
      end
      let!(:deleted_user) do
        u = create(:user)
        u.update!(deleted_at: Time.current)
        u
      end

      it 'returns only active users when status is active' do
        result = described_class.new(status: 'active').call

        expect(result[:users]).to include(user_a, user_b, user_c)
        expect(result[:users]).not_to include(suspended_user, deleted_user)
      end

      it 'returns only suspended users when status is suspended' do
        result = described_class.new(status: 'suspended').call

        expect(result[:users]).to include(suspended_user)
        expect(result[:users]).not_to include(user_a, deleted_user)
      end

      it 'returns only deleted users when status is deleted' do
        result = described_class.new(status: 'deleted').call

        expect(result[:users]).to include(deleted_user)
        expect(result[:users]).not_to include(user_a, suspended_user)
      end

      it 'excludes deleted users when no status filter is given' do
        result = described_class.new.call

        expect(result[:users]).not_to include(deleted_user)
      end
    end

    context 'with date filter' do
      it 'filters users by date_from' do
        result = described_class.new(date_from: 2.days.ago.to_date.to_s).call

        expect(result[:users]).to include(user_b, user_c)
        expect(result[:users]).not_to include(user_a)
      end

      it 'filters users by date_to' do
        result = described_class.new(date_to: 2.days.ago.to_date.to_s).call

        expect(result[:users]).to include(user_a, user_b)
        expect(result[:users]).not_to include(user_c)
      end

      it 'filters users within a date range' do
        result = described_class.new(
          date_from: 2.days.ago.to_date.to_s,
          date_to: 2.days.ago.to_date.to_s
        ).call

        expect(result[:users]).to include(user_b)
        expect(result[:users]).not_to include(user_a, user_c)
      end
    end

    context 'with sort params' do
      it 'sorts by created_at desc by default' do
        result = described_class.new(sort_by: 'created_at', sort_order: 'desc').call
        ids = result[:users].map(&:id)

        expect(ids.index(user_c.id)).to be < ids.index(user_a.id)
      end

      it 'sorts by created_at asc when specified' do
        result = described_class.new(sort_by: 'created_at', sort_order: 'asc').call
        ids = result[:users].map(&:id)

        expect(ids.index(user_a.id)).to be < ids.index(user_c.id)
      end

      it 'falls back to created_at for unsortable columns' do
        result = described_class.new(sort_by: 'invalid_column').call

        expect(result[:users]).to include(user_a, user_b, user_c)
      end
    end

    context 'with pagination' do
      it 'limits results to per_page' do
        result = described_class.new(per_page: 2, page: 1).call

        expect(result[:users].size).to eq(2)
        expect(result[:pagination][:per_page]).to eq(2)
      end

      it 'returns the second page correctly' do
        result_page1 = described_class.new(per_page: 2, page: 1).call
        result_page2 = described_class.new(per_page: 2, page: 2).call

        ids_page1 = result_page1[:users].map(&:id)
        ids_page2 = result_page2[:users].map(&:id)

        expect(ids_page1 & ids_page2).to be_empty
      end

      it 'uses DEFAULT_PER_PAGE when per_page is invalid' do
        result = described_class.new(per_page: 0).call

        expect(result[:pagination][:per_page]).to eq(Admin::UserManagementService::DEFAULT_PER_PAGE)
      end

      it 'falls back to DEFAULT_PER_PAGE when per_page exceeds MAX_PER_PAGE' do
        result = described_class.new(per_page: 999).call

        expect(result[:pagination][:per_page]).to eq(Admin::UserManagementService::DEFAULT_PER_PAGE)
      end

      it 'defaults to page 1 when page is less than 1' do
        result = described_class.new(page: 0).call

        expect(result[:pagination][:current_page]).to eq(1)
      end
    end
  end
end
