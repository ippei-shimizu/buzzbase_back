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
      quoted_table = connection.quote_table_name(table)
      table_literal = connection.quote(table)
      connection.execute(<<~SQL.squish)
        SELECT setval(
          pg_get_serial_sequence(#{table_literal}, 'id'),
          (SELECT COALESCE(MAX(id), 1) FROM #{quoted_table})
        )
      SQL
    end

    # Ruby の値を SQL リテラルに変換する。Hash / Array は jsonb キャストする。
    # 文字列リテラルは connection.quote 経由でエスケープする（ドル引用符固定だと
    # マスタ名に '$TXT$' 等が含まれた場合に構文崩壊するため）。
    def self.sql_literal(value)
      case value
      when nil
        'NULL'
      when Integer, Float, TrueClass, FalseClass
        value.to_s
      when Hash, Array
        "#{ActiveRecord::Base.connection.quote(value.to_json)}::jsonb"
      else
        ActiveRecord::Base.connection.quote(value.to_s)
      end
    end
  end
end
