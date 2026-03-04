class GroupRankingSnapshotService
  # ERAのみ昇順（低い方が良い）、他は降順
  ASC_STAT_TYPES = %w[era].freeze

  def self.record_all(date:)
    Group.find_each do |group|
      new(group, date).record
    end
  end

  def initialize(group, date)
    @group = group
    @date = date
    @members = group.accepted_users
  end

  def record
    return if @members.empty?

    record_batting_rankings
    record_pitching_rankings
  end

  private

  def record_batting_rankings
    member_ids = @members.map(&:id)

    # バルク取得でN+1を解消
    all_stats = BattingAverage.bulk_stats_for_users(member_ids)
    all_aggregates = BattingAverage.aggregate_for_users(member_ids).index_by(&:user_id)

    batting_stats = member_ids.each_with_object({}) do |user_id, hash|
      stats = all_stats[user_id]
      aggregate = all_aggregates[user_id]
      next unless stats && aggregate

      hash[user_id] = {
        batting_average: stats[:batting_average],
        home_run: aggregate.home_run.to_i,
        runs_batted_in: aggregate.runs_batted_in.to_i,
        hit: aggregate.hit.to_i,
        stealing_base: aggregate.stealing_base.to_i,
        on_base_percentage: stats[:on_base_percentage]
      }
    end

    GroupRankingSnapshot::BATTING_STAT_TYPES.each do |stat_type|
      record_ranking(stat_type, batting_stats)
    end
  end

  def record_pitching_rankings
    member_ids = @members.map(&:id)

    # バルク取得でN+1を解消
    all_stats = PitchingResult.bulk_pitching_stats_for_users(member_ids)
    all_aggregates = PitchingResult.pitching_aggregate_for_users(member_ids).index_by(&:user_id)

    pitching_stats = member_ids.each_with_object({}) do |user_id, hash|
      stats = all_stats[user_id]
      aggregate = all_aggregates[user_id]
      next unless stats && aggregate

      hash[user_id] = {
        era: stats[:era],
        win: aggregate.win.to_i,
        saves: aggregate.saves.to_i,
        hold: aggregate.hold.to_i,
        strikeouts: aggregate.strikeouts.to_i,
        win_percentage: stats[:win_percentage]
      }
    end

    GroupRankingSnapshot::PITCHING_STAT_TYPES.each do |stat_type|
      record_ranking(stat_type, pitching_stats)
    end
  end

  def record_ranking(stat_type, all_stats)
    # stat_type に該当する値を持つユーザーのみ抽出
    entries = all_stats.filter_map do |user_id, stats|
      value = stats[stat_type.to_sym]
      next unless value

      { user_id:, value: }
    end

    return if entries.empty?

    # ソート: ERAのみ昇順、他は降順
    sorted = if ASC_STAT_TYPES.include?(stat_type)
               entries.sort_by { |e| e[:value] }
             else
               entries.sort_by { |e| -e[:value] }
             end

    sorted.each_with_index do |entry, index|
      snapshot = GroupRankingSnapshot.find_or_initialize_by(
        group_id: @group.id,
        user_id: entry[:user_id],
        stat_type:,
        snapshot_date: @date
      )
      snapshot.rank = index + 1
      snapshot.value = entry[:value]
      snapshot.save!
    end
  end
end
