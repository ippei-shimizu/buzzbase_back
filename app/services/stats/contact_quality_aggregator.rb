# frozen_string_literal: true

module Stats
  # 打球の質（contact_qualities マスタ）別の集計サービス。
  #
  # contact_quality_id が記録された新仕様 PA を対象に、マスタ display_order 順で
  # count / percentage を返す。母数 0 でも全 5 カテゴリの行を出してフロント側で
  # 安定して描画できるようにする。
  class ContactQualityAggregator
    def initialize(user_id:, year: nil, match_type: nil, season_id: nil, tournament_id: nil)
      @user_id = user_id
      @year = year
      @match_type = match_type
      @season_id = season_id
      @tournament_id = tournament_id
    end

    # @return [Hash] breakdown: [{ id, label, count, percentage }], total: 集計対象の総数
    def call
      counts_by_id = filtered_scope.where.not(contact_quality_id: nil)
                                   .group(:contact_quality_id).count
      total = counts_by_id.values.sum

      breakdown = ContactQuality.order(:display_order).map do |cq|
        count = counts_by_id.fetch(cq.id, 0)
        percentage = total.zero? ? 0.0 : (count.to_f / total * 100).round(1)
        { id: cq.id, label: cq.name, count:, percentage: }
      end

      { breakdown:, total: }
    end

    private

    def filtered_scope
      @filtered_scope ||= begin
        scope = PlateAppearance.joins(game_result: :match_result)
                               .where(user_id: @user_id, is_new_format: true)
        scope = apply_year_filter(scope)
        scope = apply_match_type_filter(scope)
        scope = apply_season_filter(scope)
        apply_tournament_filter(scope)
      end
    end

    def apply_year_filter(scope)
      return scope if @year.blank? || @year.to_s == '通算'

      yr = @year.to_i
      range_start = Time.zone.local(yr, 1, 1)
      range_end = Time.zone.local(yr + 1, 1, 1)
      scope.where('match_results.date_and_time >= ? AND match_results.date_and_time < ?',
                  range_start, range_end)
    end

    def apply_match_type_filter(scope)
      return scope if @match_type.blank? || @match_type == '全て'

      scope.where(match_results: { match_type: @match_type })
    end

    def apply_season_filter(scope)
      return scope if @season_id.blank?

      scope.where(game_results: { season_id: @season_id })
    end

    def apply_tournament_filter(scope)
      return scope if @tournament_id.blank?

      scope.where(match_results: { tournament_id: @tournament_id })
    end
  end
end
