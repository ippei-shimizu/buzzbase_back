# テスト規約

## スタック

- RSpec + FactoryBot + Faker + shoulda-matchers

## リクエストスペック

```ruby
RSpec.describe 'Api::V1::GameResults', type: :request do
  let(:user) { create(:user) }

  context 'when authenticated' do
    it 'returns game results' do
      get '/api/v1/game_results', headers: auth_headers_for(user)
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.size).to eq(3)
    end
  end

  context 'when not authenticated' do
    it 'returns unauthorized' do
      get '/api/v1/game_results'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

- 認証/未認証の2分岐を基本構造とする
- 認証ヘッダーは`auth_headers_for(user)`ヘルパー使用
- JSONの検証は`response.parsed_body`で取得

## モデルスペック

- `describe '#instance_method'` / `describe '.class_method'`で階層化
- `let!`でテストデータセットアップ
- `described_class`を使用
- バリデーション: `expect(record).to be_valid` / `expect(record.errors[:field]).to include('...')`

## FactoryBot

- `sequence`でユニーク値生成
- `trait`で変形パターン定義
- `association`で関連オブジェクト自動生成
- `after(:create)`で関連データ生成が必要な場合のみコールバック使用

## 配置

- 非公開アカウント関連テストは専用ファイルに分離
- サービススペックは`spec/services/`に配置
- シリアライザスペックは`spec/serializers/`に`type: :serializer`を明示

## 競合（レース）の再現

- `transaction(requires_new: true)` の中で `create!` をスタブし、**そのブロック内で勝者レコードを作ってから raise しない**。勝者ごとセーブポイントがロールバックされ、rescue 節の引き直しが失敗する
- 勝者は `.call` の前に作り、`allow(User).to receive(:find_by).and_return(nil, nil, winner)` で「SELECT の後・INSERT の前にコミットされた」状況を作る
- 実制約に当たる検証は、Queue バリア + `use_transactional_tests = false` + `TRUNCATE` の実スレッドパターンを1本だけ添える
- バリデーションを抜いて実 DB 制約違反を起こしたいときは、private な `perform_validations` ではなく公開 API の `valid?` をスタブする

## テストの有効性を確認する

- **修正に対してテストを追加したら、修正を戻した状態で実行して落ちることを確認する**。落ちないテストは検証になっていない
  - 確認方法: `git checkout origin/<base> -- <対象ファイル>` → rspec → `git checkout HEAD -- <対象ファイル>`（`git stash` は使わない）
- 落ちない場合、別の層が先にリクエストを止めている可能性を疑う。その層を迂回する経路でテストを書き直す
  - 例: `/api/v1/auth/sign_in` は `provider='email'` で絞るため、パスワードが残っていても 401 になる。provider を見ない `/users/sign_in` なら差が出る
- **「含まれないこと」を見る assertion（`not_to include(...)`）は、壊れた実装で実際に出力される文字列を比較対象にする**。例: リセットメールが誤送信されたとき本文に出るのはトークンの値であって `reset_password_token` という文字列ではないので、`not_to include('reset_password_token')` は常に通る。`password/edit` のようにリンクに必ず含まれる部分を見る
- 同じ assertion をユニットとリクエストの両方に置かない。リクエストスペックでは「外から観測できる振る舞い」を見る
