# frozen_string_literal: true

# golden master（characterization）テストの比較ヘルパー。
#
# サービスの出力を JSON で spec/golden/ に固定し、以降の実行で完全一致を検証する。
# 集計ロジックが意図せず変わると差分で必ず落ちる。
#
# golden を意図的に更新するとき:
#   SPEC_UPDATE_GOLDEN=1 bundle exec rspec spec/qa
# 未生成の golden は初回実行時に自動生成され、その example は pending 扱いになる。
module GoldenMaster
  GOLDEN_DIR = Rails.root.join('spec/golden')

  module_function

  # data を canonical 化し、保存済み golden と比較する。
  # 例: expect(GoldenMaster.compare('headline_stats', result)).to be_golden_match
  # と書けるよう、[actual, expected] か :written を返す。
  def load_or_write(name, data)
    actual = canonicalize(JSON.parse(data.to_json))
    path = GOLDEN_DIR.join("#{name}.json")

    if ENV['SPEC_UPDATE_GOLDEN'] == '1' || !path.exist?
      GOLDEN_DIR.mkpath
      path.write("#{JSON.pretty_generate(actual)}\n")
      return :written
    end

    [actual, canonicalize(JSON.parse(path.read))]
  end

  # ハッシュのキー順・配列の順序に依存しない比較のため再帰的に正規化する。
  # 配列は要素の JSON 文字列でソートし、ハッシュはキーでソートする。
  def canonicalize(obj)
    case obj
    when Hash
      obj.sort_by { |k, _| k.to_s }.to_h.transform_values { |value| canonicalize(value) }
    when Array
      obj.map { |element| canonicalize(element) }.sort_by(&:to_json)
    else
      obj
    end
  end
end

module GoldenMasterHelper
  # golden と比較する。未生成なら baseline を書き出して pending にする。
  def expect_golden(name, data)
    result = GoldenMaster.load_or_write(name, data)
    if result == :written
      skip "golden baseline を生成しました: spec/golden/#{name}.json（再実行で検証されます）"
    else
      actual, expected = result
      expect(actual).to eq(expected)
    end
  end
end

RSpec.configure do |config|
  config.include GoldenMasterHelper, type: :service
end
