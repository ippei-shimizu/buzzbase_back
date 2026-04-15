# コントローラー設計ルール

## 基本方針: CRUDに帰着させる

- 7アクションのみ: `index`, `show`, `new`, `edit`, `create`, `update`, `destroy`
- カスタムアクションが欲しくなったら**新しいコントローラーを切る**
- 例: `POST /cards/:id/close` ではなく `Cards::ClosuresController#create`

## 認証とリソース取得

- `before_action :authenticate_api_v1_user!, only: %i[create update destroy]`
- リソース取得はスコープを絞る: `current_api_v1_user.game_results.find(params[:id])`
- **非公開アカウントガード必須**: 他ユーザーのデータを返す前に `user.profile_visible_to?(current_api_v1_user)` をチェック

## レスポンス形式（v2パターンで統一）

```ruby
# 成功
render json: resource, serializer: V2::XxxSerializer, status: :ok
render json: resource, serializer: V2::XxxSerializer, status: :created

# エラー
render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity

# 削除
render json: { message: '削除しました' }, status: :ok

# 非公開
render json: { error: 'このアカウントは非公開です' }, status: :forbidden

# ページネーション
paginated_response(resources, V2::XxxSerializer)
```

## 新機能の実装

- **v2パターン**で実装する（シリアライザ使用、N+1回避）
- v1のモデル`.map`でハッシュ変換するパターンは使わない
- エラーメッセージは日本語
- ルーティングは`resources`に`only:`を明示して不要なルートを生やさない
