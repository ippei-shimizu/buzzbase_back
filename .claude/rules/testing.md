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
