# frozen_string_literal: true

module Stats
  module Concerns
    # 投球コース（5x5 グリッド、捕手目線）集計の共通ロジック。
    # PitchCourseAggregator / PitchCoursePitchTypeAggregator で共有する。
    #
    # 「打っていないコース」自体が情報になるため、母数の少ないセルも行を落とさず
    # is_reliable フラグを付けて返し、表示上の扱いはクライアントに委ねる。
    module PitchCourseZoneConcern
      extend ActiveSupport::Concern

      # 打数がこの値未満のコースは is_reliable: false（参考値表示）。
      # PitcherFaceoffAggregator::MIN_PLATE_APPEARANCES と揃える。
      MIN_AT_BATS = 3

      private

      # @param course [Integer] 1〜25（捕手目線・行優先）
      # @param bucket [Hash] plate_appearances / at_bats / hits の集計値
      # @return [Hash] グリッド1セル分の集計行
      def build_zone(course, bucket)
        at_bats = bucket[:at_bats]
        hits = bucket[:hits]
        {
          course:,
          row: ((course - 1) / 5) + 1,
          col: ((course - 1) % 5) + 1,
          is_strike_zone: PlateAppearance::STRIKE_ZONE_COURSES.include?(course),
          plate_appearances: bucket[:plate_appearances],
          at_bats:,
          hits:,
          batting_average: safe_divide(hits, at_bats),
          is_reliable: at_bats >= MIN_AT_BATS
        }
      end

      # ストライクゾーン / ボールゾーンなど、複数セルをまとめた集計。
      def zone_summary(zones)
        at_bats = zones.sum { |z| z[:at_bats] }
        hits = zones.sum { |z| z[:hits] }
        {
          plate_appearances: zones.sum { |z| z[:plate_appearances] },
          at_bats:,
          hits:,
          batting_average: safe_divide(hits, at_bats)
        }
      end

      def accumulate_zone(bucket, result_id, counted, cnt)
        bucket[:plate_appearances] += cnt
        bucket[:at_bats] += cnt if counted
        bucket[:hits] += cnt if ::Stats::BattingAverageRecalculator::HIT_RESULT_IDS.include?(result_id)
      end

      def empty_zone_bucket
        { plate_appearances: 0, at_bats: 0, hits: 0 }
      end
    end
  end
end
