module MasterData
  # マスタテーブルへの冪等なシード投入を共通化するヘルパー。
  # マイグレーション内 `up` から呼び、ON CONFLICT (id) DO UPDATE で重複時も整合させる。
  # シーケンスは MAX(id) まで進めるため、本来 1 起算のシードのみ想定する。
  module Seeder
    SEED_DATA_DIR = Rails.root.join('db/data/master_seeds').freeze

    # YAML ファイルに定義された rows を upsert する。
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] migration の connection
    # @param table [String] 投入先テーブル名
    # @param file [String] db/data/master_seeds 以下のファイル名（例: "pitch_types.yml"）
    def self.from_yaml(connection, table:, file:)
      rows = YAML.load_file(SEED_DATA_DIR.join(file))
      # Seeder.upsert_all は ActiveRecord の upsert_all とは異なる独自実装の生SQL投入。
      # rubocop:disable Rails/SkipsModelValidations
      upsert_all(connection, table:, rows:)
      # rubocop:enable Rails/SkipsModelValidations
    end

    # 任意の rows を upsert する。
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
    # @param table [String]
    # @param rows [Array<Hash>] id を含む各行
    def self.upsert_all(connection, table:, rows:)
      return if rows.empty?

      now = Time.current.utc.strftime('%Y-%m-%d %H:%M:%S')
      columns = rows.first.keys

      rows.each do |row|
        values = columns.map { |c| sql_literal(row[c]) }
        assignments = columns.reject { |c| c.to_s == 'id' }.map { |c| "#{c} = EXCLUDED.#{c}" }
        connection.execute(<<~SQL.squish)
          INSERT INTO #{table} (#{columns.join(', ')}, created_at, updated_at)
          VALUES (#{values.join(', ')}, '#{now}', '#{now}')
          ON CONFLICT (id) DO UPDATE SET
            #{assignments.join(', ')},
            updated_at = EXCLUDED.updated_at
        SQL
      end

      reset_sequence(connection, table)
    end

    # シーケンスを MAX(id) まで進める。
    def self.reset_sequence(connection, table)
      connection.execute(<<~SQL.squish)
        SELECT setval(
          pg_get_serial_sequence('#{table}', 'id'),
          (SELECT COALESCE(MAX(id), 1) FROM #{table})
        )
      SQL
    end

    # Ruby の値を SQL リテラルに変換する。Hash / Array は jsonb キャストする。
    def self.sql_literal(value)
      case value
      when nil
        'NULL'
      when Integer, Float, TrueClass, FalseClass
        value.to_s
      when Hash, Array
        "$JSON$#{value.to_json}$JSON$::jsonb"
      else
        "$TXT$#{value}$TXT$"
      end
    end
  end
end
