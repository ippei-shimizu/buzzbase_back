# frozen_string_literal: true

# v1 API レスポンスの「形（キー・型・null 許容）」を spec/golden_v1/*.json に固定する。
#
# 旧モバイルクライアント（App Store / Google Play 配信中）は v1 API を使い続けるため、
# v2 開発・リファクタの副作用で v1 のレスポンス形が壊れると即障害になる。値そのものは
# 固定せず（変動するため）、構造（キー集合と各値の型）だけを固定して破壊的変更を検知する。
#
# golden を意図的に更新するとき:
#   SPEC_UPDATE_GOLDEN=1 bundle exec rspec spec/requests/api/v1/schema_snapshot_spec.rb
module V1SchemaSnapshot
  GOLDEN_DIR = Rails.root.join('spec/golden_v1')

  SCALAR_TYPES = {
    String => 'String', Integer => 'Integer', Float => 'Float',
    TrueClass => 'Boolean', FalseClass => 'Boolean', NilClass => 'null'
  }.freeze

  module_function

  # レスポンス body から型スキーマを再帰的に抽出する。
  # 配列は先頭要素の型で代表させる（同型前提）。null は 'null' として記録する。
  def schema_of(value)
    case value
    when Hash then value.keys.sort.index_with { |key| schema_of(value[key]) }
    when Array then value.empty? ? [] : [schema_of(value.first)]
    else SCALAR_TYPES[value.class] || value.class.name
    end
  end

  def load_or_write(name, body)
    actual = JSON.parse(schema_of(body).to_json)
    path = GOLDEN_DIR.join("#{name}.json")

    if ENV['SPEC_UPDATE_GOLDEN'] == '1' || !path.exist?
      GOLDEN_DIR.mkpath
      path.write("#{JSON.pretty_generate(actual)}\n")
      return :written
    end

    [actual, JSON.parse(path.read)]
  end
end

module V1SchemaSnapshotHelper
  # v1 レスポンスの形を golden と比較する。未生成なら baseline を書いて pending にする。
  def expect_v1_schema(name, body)
    result = V1SchemaSnapshot.load_or_write(name, body)
    if result == :written
      skip "v1 schema baseline を生成しました: spec/golden_v1/#{name}.json（再実行で検証されます）"
    else
      actual, expected = result
      expect(actual).to eq(expected)
    end
  end
end

RSpec.configure do |config|
  config.include V1SchemaSnapshotHelper, type: :request
end
