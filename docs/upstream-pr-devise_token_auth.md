# devise_token_auth へアップストリーム PR を出す手順

`lib/devise_token_auth/concerns/user.rb` の `clean_old_tokens` に潜む 2 つのバグについて、本家 (https://github.com/lynndylanhurley/devise_token_auth) にバグ報告 / 修正 PR を提出するための作業メモ。BUZZ BASE 側ではすでに User モデルで override 済みのため緊急性はないが、本家が修正を受け入れれば override を将来削除できる。

OSS への PR 提出経験がない人向けに、流れと注意点を一通り書いている。

## 提出する内容

### バグ 1: 新規 token が attribute mutation tracking との衝突で消える

```ruby
# vendor/.../devise_token_auth-1.2.6/.../user.rb 内
self.tokens = tokens_to_keep.sort_by { |_cid, v| v[:expiry] || v['expiry'] }.to_h
```

`self.tokens =` で Hash オブジェクトを丸ごと差し替える経路を踏むため、直前に `create_token` が `tokens[token.client] = {...}` で追加した新規 client_id の entry が ActiveRecord の attribute mutation tracking との衝突で読み戻し時に nil になる。次の `build_auth_headers` 内 `tokens[client]['expiry']` で `NoMethodError: undefined method '[]' for nil:NilClass` が発生。

### バグ 2: `max_lifespan_expiry` の計算式が `TokenFactory.expiry` と不整合

- `TokenFactory.expiry`: `(Time.zone.now + lifespan).to_i` （calendar advance、月により 30〜31 日）
- `clean_old_tokens`: `Time.now.to_i + lifespan.to_i` （固定 30.4375 日）

31 日ある月（5 月など）に新規 token の expiry が max_lifespan_expiry を超え、`delete_if` 相当の処理で削除されてしまう。

### 修正後の実装

```ruby
def clean_old_tokens
  return if tokens.blank? || !max_client_tokens_exceeded?

  max_lifespan_expiry = (Time.zone.now + DeviseTokenAuth.token_lifespan).to_i
  tokens.delete_if { |_cid, v| (v[:expiry] || v['expiry']).to_i > max_lifespan_expiry }

  while max_client_tokens_exceeded?
    oldest_cid, = tokens.min_by { |_cid, v| (v[:expiry] || v['expiry']).to_i }
    break unless oldest_cid

    tokens.delete(oldest_cid)
  end
end
```

ポイント：

- `self.tokens =` を排除し、`delete_if` / `delete` で同一 Hash オブジェクトへの in-place mutation のみに変更
- `max_lifespan_expiry` を `TokenFactory.expiry` と同じ式 `(Time.zone.now + lifespan).to_i` に揃える

### 追加するリグレッションテスト

devise_token_auth のテストは MiniTest 系。`test/models/devise_token_auth/concerns/user_test.rb` 等に追加する想定。

```ruby
# 概念サンプル (MiniTest 形式)
def test_create_new_auth_token_at_max_devices_boundary
  user = create_user
  max_devices = DeviseTokenAuth.max_number_of_devices
  full_set = (1..max_devices).each_with_object({}) do |i, h|
    h["client_#{i}"] = { 'token' => 'hash', 'expiry' => Time.now.to_i + 60 + i }
  end
  user.update_columns(tokens: full_set)
  user.reload

  headers = user.create_new_auth_token

  assert_equal max_devices, user.reload.tokens.keys.count
  assert_includes user.tokens.keys, headers['client']
end
```

このテストは現状の master HEAD で **必ず落ちる**（本障害の再現）ことが価値。修正を当てると pass する。

## 提出先

| 種類 | URL |
|---|---|
| 本家リポジトリ | https://github.com/lynndylanhurley/devise_token_auth |
| Issue tracker | https://github.com/lynndylanhurley/devise_token_auth/issues |
| Pull request | https://github.com/lynndylanhurley/devise_token_auth/pulls |

事前検索（重複していないか確認）：

```bash
gh issue list --repo lynndylanhurley/devise_token_auth --search "clean_old_tokens" --state all
gh pr list --repo lynndylanhurley/devise_token_auth --search "clean_old_tokens" --state all
```

## 推奨フロー

### A. Issue 先行（おすすめ）

devise_token_auth は中規模 OSS でメンテナの数も限られるため、いきなり PR を出すよりまず Issue を立てて再現条件と原因を共有し、メンテナの反応を見てから PR を出すほうが通りやすい。

### B. PR 直接

修正が明確で簡単な場合は PR 直接でも OK。本件は変更箇所が小さく、テストで再現が示せるので PR 直接でも筋は通る。

## ステップごとの手順（PR 直接ルート）

### Step 1. 事前準備

CONTRIBUTING.md / README.md / 過去 PR を確認：

```bash
gh repo clone lynndylanhurley/devise_token_auth /tmp/dta-check
cat /tmp/dta-check/CONTRIBUTING.md 2>/dev/null || echo "no CONTRIBUTING.md"
cat /tmp/dta-check/README.md | grep -A 20 -i "contributing"

# 直近マージされた PR を 3 件ほど読んでスタイルを掴む
gh pr list --repo lynndylanhurley/devise_token_auth --state merged --limit 5
gh pr view <番号> --repo lynndylanhurley/devise_token_auth
```

CLA は **不要**（多くの Rails 系 OSS と同様、本家リポジトリで明示要求なし）。

### Step 2. Fork & Clone

GitHub Web UI で本家を Fork → 自分のアカウントに `ippei-shimizu/devise_token_auth` ができる。

```bash
cd ~/projects   # 作業用ディレクトリ
git clone git@github.com:ippei-shimizu/devise_token_auth.git
cd devise_token_auth
git remote add upstream git@github.com:lynndylanhurley/devise_token_auth.git
git fetch upstream
git checkout -b fix/clean-old-tokens-mutation-and-expiry upstream/master
```

- `origin` = 自分の fork
- `upstream` = 本家
- 作業ブランチは upstream/master から派生

### Step 3. ローカル開発環境を立てる

devise_token_auth は `test/dummy/` に Rails dummy app が同梱されている：

```bash
# Ruby バージョンを Gemfile に合わせる (rbenv 等で)
bundle install

cd test/dummy
bundle exec rails db:create db:migrate
cd ../..

# 既存テストが全部通ることを確認 (壊れた状態でスタートしないため)
bundle exec rake test
```

通らなければ、まずは「環境問題か、本当にバグってるか」を切り分け。

### Step 4. 修正コードを当てる

`app/models/devise_token_auth/concerns/user.rb` の `clean_old_tokens` を上記「修正後の実装」に差し替える。

### Step 5. テスト追加

`test/` 配下を探して、User モデル / clean_old_tokens 周りのテストファイルに上記のリグレッションテストを追加。命名は既存スタイルに合わせる。

### Step 6. テスト全実行 + Rubocop

```bash
bundle exec rake test
bundle exec rubocop
```

両方 green になることを確認。CI が GitHub Actions で動くので、ローカルでも同じ条件を通しておく。

### Step 7. commit / push / PR

```bash
git add -A
git commit -m "Fix attribute mutation race and lifespan mismatch in clean_old_tokens"
git push origin fix/clean-old-tokens-mutation-and-expiry
```

GitHub の自分の fork ページにアクセスすると「Compare & pull request」ボタンが出る。本家リポジトリ (`lynndylanhurley/devise_token_auth`) の `master` ブランチへの PR を作成。

## PR description テンプレ（英語）

PR Title:

```
Fix attribute mutation race and lifespan mismatch in clean_old_tokens
```

Body:

````markdown
## Problem

`User#clean_old_tokens` has two bugs that cause `create_new_auth_token` to raise `NoMethodError: undefined method '[]' for nil:NilClass` for users whose `tokens.length == DeviseTokenAuth.max_number_of_devices`.

### Bug 1: Attribute reassignment loses the newly added token

```ruby
self.tokens = tokens_to_keep.sort_by { |_cid, v| v[:expiry] || v['expiry'] }.to_h
```

This replaces the whole Hash object. When `create_token` has just done `tokens[token.client] = {...}`, ActiveRecord's attribute mutation tracking can lose the freshly added entry on the next read, so the subsequent `build_auth_headers` call sees `tokens[client]` as `nil`.

### Bug 2: `max_lifespan_expiry` formula inconsistent with `TokenFactory.expiry`

- `TokenFactory.expiry` uses `(Time.zone.now + lifespan).to_i` (calendar advance, 30 or 31 days depending on the month).
- `clean_old_tokens` uses `Time.now.to_i + lifespan.to_i` (fixed 30.4375 days).

In 31-day months, a freshly created token has `expiry > max_lifespan_expiry` and gets filtered out before being usable.

## Fix

Re-implement `clean_old_tokens` using only in-place mutation (`delete_if` / `delete`) and align `max_lifespan_expiry` with `TokenFactory.expiry`.

```ruby
def clean_old_tokens
  return if tokens.blank? || !max_client_tokens_exceeded?

  max_lifespan_expiry = (Time.zone.now + DeviseTokenAuth.token_lifespan).to_i
  tokens.delete_if { |_cid, v| (v[:expiry] || v['expiry']).to_i > max_lifespan_expiry }

  while max_client_tokens_exceeded?
    oldest_cid, = tokens.min_by { |_cid, v| (v[:expiry] || v['expiry']).to_i }
    break unless oldest_cid

    tokens.delete(oldest_cid)
  end
end
```

## Tests

Added a regression test that fills `tokens` up to `max_number_of_devices`, calls `create_new_auth_token`, and asserts:

1. No exception is raised
2. The newly returned `client_id` is present in `tokens`
3. `tokens.length == max_number_of_devices`

This test fails on master without the fix, reproducing the production incident.

## Real-world impact

We hit this in production after upgrading from 1.2.2 to 1.2.6 on Rails 7.1 in May 2026 (a 31-day month). Roughly 1% of our users (9 out of ~1,200) were blocked from logging in until we patched our app-level model with an override.
````

## Issue 先行ルートの場合

Issue Title:

```
clean_old_tokens drops the freshly added token in 31-day months, causing 500 on create_new_auth_token
```

Body: 上記の PR description から `## Fix` / `## Tests` を「## Proposed fix」「## Test plan」に書き換えて、最後に "Happy to send a PR if this looks correct." と付け加える形が定番。

## レビュー対応のコツ

- CI (GitHub Actions) が落ちたら原因を直して再 push
- メンテナのコメントには 24h 以内に返事を返すのが望ましい（マージ意欲を保つため）
- スコープ拡大の要求が来たら別 PR に切ってもらえないか相談（PR 単位は小さく保つ）
- 反応が長期間無い場合は、PR コメントで `@lynndylanhurley friendly bump, anything else needed?` のように軽く催促（1〜2 週間に 1 回程度）

## メンテ状況の現実

- 1.2.6 が現時点 (2026-05) の最新版（2025-11-21 リリース）
- それ以降 6 ヶ月リリースなし
- 直近の master 活動は CI まわりや devise 5 対応など
- バグ修正 PR の取り込みは早ければ数日、遅いと数ヶ月 〜 マージされない場合もある

PR を出しても **数ヶ月マージされない可能性**を覚悟する。BUZZ BASE 側の override は本家がリリースして bump できるまで残しておく前提。

## 放置された場合のフォールバック

### 案A. 自分の fork から Gemfile で参照

```ruby
# BUZZ BASE の Gemfile
gem 'devise_token_auth', git: 'https://github.com/ippei-shimizu/devise_token_auth',
                         branch: 'fix/clean-old-tokens-mutation-and-expiry'
```

メリット: gem 本体に修正が当たり、override を消せる。
デメリット: fork の保守責任を持つ（本家 master の更新に追従する必要）。

### 案B. 現状の override 継続

BUZZ BASE の `app/models/user.rb` の override をそのまま維持。本家がリリースするまで凌ぐ。運用としてはこれが最も楽。

## 関連

- BUZZ BASE Issue: #340, #342
- BUZZ BASE PR: #225 (Issue #340 対応), #230 (Issue #342 根本対応)
- BUZZ BASE 側の override: `back/app/models/user.rb` の `clean_old_tokens`
- devise_token_auth リポジトリ: https://github.com/lynndylanhurley/devise_token_auth
- 関連 gem ファイル: `vendor/bundle/ruby/3.2.0/gems/devise_token_auth-1.2.6/app/models/devise_token_auth/concerns/user.rb`
