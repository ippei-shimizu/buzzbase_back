# frozen_string_literal: true

module Stats
  module Concerns
    # 投球コース（5x5 グリッド、捕手目線）集計の共通ロジック。
    # PitchCourseAggregator / PitchCoursePitchTypeAggregator / PitcherFaceoffCourseAggregator で共有する。
    #
    # 「打っていないコース」自体が情報になるため、母数の少ないセルも行を落とさず
    # is_reliable フラグを付けて返し、表示上の扱いはクライアントに委ねる。
    module PitchCourseZoneConcern
      extend ActiveSupport::Concern

      # 打数がこの値未満のコースは is_reliable: false（参考値表示）。
      # PitcherFaceoffAggregator::MIN_PLATE_APPEARANCES と揃える。
      MIN_AT_BATS = 3

      # 指標（打率・長打率・三振率など）はクライアントで計算するため、率ではなく生カウントを返す。
      COUNT_KEYS = %i[plate_appearances at_bats hits total_bases strikeouts swinging_strikeouts looking_strikeouts].freeze

      private

      # @param course [Integer] 1〜25（捕手目線・行優先）
      # @param bucket [Hash] COUNT_KEYS の集計値
      # @return [Hash] グリッド1セル分の集計行
      def build_zone(course, bucket)
        {
          course:,
          row: ((course - 1) / 5) + 1,
          col: ((course - 1) % 5) + 1,
          is_strike_zone: PlateAppearance::STRIKE_ZONE_COURSES.include?(course),
          **bucket.slice(*COUNT_KEYS),
          batting_average: safe_divide(bucket[:hits], bucket[:at_bats]),
          is_reliable: bucket[:at_bats] >= MIN_AT_BATS
        }
      end

      # ストライクゾーン / ボールゾーンなど、複数セルをまとめた集計。
      def zone_summary(zones)
        counts = COUNT_KEYS.index_with { |key| zones.sum { |zone| zone[key] } }
        counts.merge(batting_average: safe_divide(counts[:hits], counts[:at_bats]))
      end

      # @param swing_type [String, nil] enum label（'swinging' / 'looking'）。三振 (id=13) のときだけ入る
      def accumulate_zone(bucket, result_id, counted, swing_type, count)
        bucket[:plate_appearances] += count
        bucket[:at_bats] += count if counted
        bucket[:hits] += count if ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS.include?(result_id)
        bucket[:total_bases] += ::Stats::BattingAverageRecalculator::TOTAL_BASES_BY_RESULT_ID.fetch(result_id, 0) * count
        accumulate_strikeout(bucket, result_id, swing_type, count)
      end

      def accumulate_strikeout(bucket, result_id, swing_type, count)
        return unless ::Stats::BattingAverageRecalculator::STRIKE_OUT_IDS.include?(result_id)

        bucket[:strikeouts] += count
        bucket[:swinging_strikeouts] += count if swing_type == 'swinging'
        bucket[:looking_strikeouts] += count if swing_type == 'looking'
      end

      def empty_zone_bucket
        COUNT_KEYS.index_with(0)
      end
    end
  end
end
