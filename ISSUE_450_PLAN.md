# Issue #450 対応プラン

## Context

mobile版Proを先行リリースするにあたり、back PR #216 / mobile PR #80 の多角的レビュー（issue #450）で見つかった16件の考慮漏れ・バグ・デグレに対応する。作業ブランチは back/mobile とも `fix/450-pro-review-fixes`（起点: `release/pro-202605`）。

ユーザーの希望により、各項目の対応方針を1つずつ質問し、全16件について合意形成済み（実装対応するもの・調査の結果対応不要と判断したもの・今回は見送るものに分類済み）。以下は確定した対応方針。

## 調査により優先度が変わった項目

- **back-高2（v1 baseball_notes の `game_result_id` 消失）**: front は v1 baseball_notes API（create/update/delete）を実際に使用しているが、`game_result_id` フィールド自体はfrontのどこにも参照されていない（型定義・画面表示ともになし）。back内にも `.game_result_id` への直接参照はなく実行時エラーもない。→ **実害なし、優先度「低」に格下げ**（対応するとしても最後）
- **back-高3（グループ招待リンクの1件上限）**: mobile側 `app/(tabs)/(groups)/join.tsx` は `hasEntitlement("unlimited_groups")` と所属数を事前チェックし、上限時は `PaywallModal` でアップセル表示する設計が既に実装済み（`create.tsx` も同様）。→ **mobile単独リリースには対応不要**（front側の同等機能は front 対応時に検討）

## 合意済み項目（対応方針が確定したもの）

### 1. back-高1: RevenueCat EXPIRATIONのイベント順序逆転ガード欠如

**方針**: `ExpirationHandler`に個別ガードを追加（最小修正、RenewalHandlerと同パターン）

```ruby
class ExpirationHandler < BaseHandler
  def call
    with_resolved_subscription do |user, subscription|
      next if outdated_expiration?(subscription.expires_at, payload.expiration_at)

      subscription.update!(status: 'expired', last_synced_at: Time.current)
      event_recorder.record(user, subscription, 'expired')
      SubscriptionExpiredNotificationJob.perform_now(user.id)
    end
  end

  private

  def outdated_expiration?(current_expires_at, event_expires_at)
    current_expires_at.present? && event_expires_at.present? && current_expires_at > event_expires_at
  end
end
```

対象ファイル: `back/app/services/revenue_cat/handlers/expiration_handler.rb`
テスト追加: `spec/services/revenue_cat/handlers/expiration_handler_spec.rb`（新しいRENEWALで延長済みのexpires_atがある状態で古いEXPIRATIONが届いてもstatusが変わらないこと）

### 2. mobile-高: 課金成功後の同期失敗が「購入失敗」と誤表示される

**方針**: 最小修正。`purchasePackage()`が成功した時点で「購入成功」とし、以降の`syncProStatus()`失敗はSentryに記録するのみで購入失敗表示にはしない。

対象ファイル（同一パターンが重複しているため両方修正）:
- `mobile/components/pro/PaywallModal.tsx`（`handlePurchase`, L467-490）
- `mobile/app/pro/index.tsx`（同等の`handlePurchase`実装）

修正イメージ:
```ts
const handlePurchase = async () => {
  if (!selectedPackage) return;
  setPurchasing(true);
  try {
    await purchasePackage(selectedPackage);
  } catch (error) {
    if (isUserCancelled(error)) return setPurchasing(false);
    Sentry.captureException(error, { tags: { source: "revenue_cat_purchase" } });
    showSnackbar({ type: "error", message: "購入に失敗しました。時間を置いて再度お試しください" });
    return setPurchasing(false);
  }

  // ここから先、Appleへの課金は既に成功している。sync失敗は「購入失敗」にしない。
  try {
    await syncProStatus();
  } catch (error) {
    Sentry.captureException(error, { tags: { source: "revenue_cat_purchase_sync" } });
  }
  await queryClient.invalidateQueries({ queryKey: ["pro", "status"] });
  setPurchasing(false);
  onClose();
  router.push("/pro/success");
};
```

テスト追加: `syncProStatus`が例外を投げても`router.push("/pro/success")`が呼ばれること（`PaywallModal.test.tsx`, `app/pro/__tests__/index.test.tsx`）

### 3. mobile-高: `pro_features` 機能フラグのキルスイッチが効いていない

**方針**: バグ修正 + テストも修正

対象ファイル: `mobile/app/account/subscription/index.tsx`（L19,23）

```ts
const { enabled: proFeatures } = useFeatureFlag("pro_features");
// ...
if (!proFeatures) return <Redirect href="/" />;
```

テスト修正: `mobile/app/account/subscription/__tests__/index.test.tsx:57`。現状`router.push`が呼ばれないことだけを見ているが、`<Redirect>`はpushを呼ばない宣言的コンポーネントのため検知できない。`useFeatureFlag`をfalseにモックした状態で、Redirect先の画面要素（またはナビゲーションのモック側でRedirect呼び出し）が描画されないことを検証する形に直す。

### 4. mobile-高: APIエラーと「未加入」が区別されない

**方針**: サブスクリプション画面のみ修正（範囲限定）

対象ファイル: `mobile/app/account/subscription/index.tsx`

```ts
const { proStatus, isLoading, isError, refetch } = useProStatus();
// ...
if (isError) {
  return (
    <View style={styles.center}>
      <Text style={styles.errorText}>状態の取得に失敗しました</Text>
      <TouchableOpacity onPress={() => refetch()} accessibilityRole="button">
        <Text>再試行</Text>
      </TouchableOpacity>
    </View>
  );
}
```

`useEntitlement`側への`isError`伝播・ProGate等の見直しは対応範囲外（TanStack Queryのキャッシュにより初回取得失敗時のみの限定的影響のため）。

### 5. back-中: Webhook二重配信時の排他制御なし（lost update）

**方針**: 悲観的ロック（`with_lock`）

対象ファイル: `back/app/services/revenue_cat/handlers/base_handler.rb`（`with_resolved_subscription`）

```ruby
def with_resolved_subscription(require_persisted: true, require_known_product: false)
  user = UserResolver.resolve(payload.app_user_id)
  return UserResolver.notify_unknown(payload.app_user_id) unless user

  subscription = user.subscription_or_default
  return if require_persisted && !subscription.persisted?
  return if require_known_product && unknown_product?

  if subscription.persisted?
    subscription.with_lock { yield user, subscription }
  else
    yield user, subscription
  end
end
```

テスト追加: 並行更新を模したテスト（2スレッド、または`with_lock`が呼ばれることをモックで検証）を`spec/services/revenue_cat/handlers/base_handler_spec.rb`等に追加

### 6. back-中: `after_commit :recalculate_activity` の同期実行

**方針**: 同期のまま、rescueで分離（最小修正）

対象ファイル: `back/app/models/match_result.rb`（`recalculate_activity`メソッド）

```ruby
def recalculate_activity
  [date_and_time, previous_date_and_time].compact.uniq.each do |time|
    Activities::DailyActivityRecalculator.new(
      user_id:, date: time.in_time_zone('Asia/Tokyo').to_date
    ).call
  end
rescue StandardError => e
  Sentry.capture_exception(e, tags: { source: "match_result_recalculate_activity" })
end
```

テスト追加: `DailyActivityRecalculator`が例外を投げても`match_result`の保存自体は成功すること（`spec/models/match_result_spec.rb`）

### 7. back-中: Subscriptionバックフィルマイグレーションが並行登録とレースする

**方針**: 対応不要。PostgreSQLの単一INSERT...SELECT文はstatement開始時の1スナップショットで実行されるため、指摘された並行登録との真のraceは実質起きない。対応なしで終了。

### 8. back-中: アカウント削除がPro加入中はブロックされる（mobile未対応）

**方針**: `pro_active`エラーコードを取得して専用文言を表示、解約画面への導線を付ける

対象ファイル: `mobile/app/(tabs)/(profile)/account-deletion.tsx`

```ts
onPress: async () => {
  setIsDeleting(true);
  try {
    await deleteAccount();
    await logout();
  } catch (error) {
    setIsDeleting(false);
    const code = axios.isAxiosError(error) ? error.response?.data?.error : null;
    if (code === "pro_active") {
      Alert.alert(
        "削除できません",
        "Pro加入中のため、先に解約してください。",
        [
          { text: "キャンセル", style: "cancel" },
          { text: "解約する", onPress: () => router.push("/account/subscription") },
        ],
      );
      return;
    }
    Alert.alert("エラー", "アカウントの削除に失敗しました");
  }
},
```

`useRouter`のimport追加が必要。テスト追加: `pro_active`エラー時に専用ダイアログが出ることを検証

### 9. back-中: 同一Webhookイベントが同時到達した際、片方が500になる

**方針**: `RecordNotUnique`をrescueして既存行を返す

対象ファイル: `back/app/models/webhook_event.rb`（`find_or_create_pending!`）

```ruby
def self.find_or_create_pending!(provider:, external_event_id:, event_type:, payload:)
  find_or_create_by!(provider:, external_event_id:) do |we|
    we.event_type = event_type
    we.payload = payload
    we.received_at = Time.current
    we.status = 'pending'
  end
rescue ActiveRecord::RecordNotUnique
  find_by!(provider:, external_event_id:)
end
```

Stripe/RevenueCat両方のwebhookコントローラで共通利用しているため、この1箇所の修正で両方に効く。
テスト追加: 同一`external_event_id`で2回連続作成を試みても例外にならず同一レコードが返ること

### 10. back-中: Web決済完了後のPro有効化監視なし

**方針**: 今回は見送り。別issueとして後日対応する。

### 11. mobile-中: 購入復元で対象0件でも「復元しました」と成功表示される

**方針**: `entitlements.active`を確認して分岐

対象ファイル: `mobile/components/pro/PaywallModal.tsx`（`handleRestore`）、`mobile/app/pro/index.tsx`（同等実装）

```ts
const handleRestore = async () => {
  setRestoring(true);
  try {
    const customerInfo = await restorePurchases();
    await syncProStatus();
    await queryClient.invalidateQueries({ queryKey: ["pro", "status"] });

    const hasActiveEntitlement =
      Object.keys(customerInfo.entitlements.active).length > 0;
    if (hasActiveEntitlement) {
      showSnackbar({ type: "success", message: "購入情報を復元しました" });
      onClose();
    } else {
      showSnackbar({
        type: "info",
        message: "復元できる購入情報がありませんでした",
      });
    }
  } catch {
    showSnackbar({ type: "error", message: "復元に失敗しました。時間を置いて再度お試しください" });
  } finally {
    setRestoring(false);
  }
};
```

### 12. mobile-中: 二重タップ防止が`disabled`プロパティのみに依存

**方針**: 関数先頭にガードを追加

対象ファイル: `mobile/components/pro/PaywallModal.tsx`, `mobile/app/pro/index.tsx`

```ts
const handlePurchase = async () => {
  if (!selectedPackage || purchasing) return;
  setPurchasing(true);
  // ...
};

const handleRestore = async () => {
  if (restoring) return;
  setRestoring(true);
  // ...
};
```

### 13. mobile-中: RevenueCatのエラーコードが出し分けされていない

**方針**: 主要2つ（PAYMENT_PENDING_ERROR, PRODUCT_ALREADY_PURCHASED_ERROR）を出し分け

対象ファイル: `mobile/components/pro/PaywallModal.tsx`（`handlePurchase`のcatch節）、`mobile/app/pro/index.tsx`（同等実装）

```ts
} catch (error: unknown) {
  if (isUserCancelled(error)) return;
  const code = (error as { code?: string })?.code;
  if (code === PURCHASES_ERROR_CODE.PAYMENT_PENDING_ERROR) {
    showSnackbar({ type: "info", message: "お支払いが保留中です。承認が完了し次第、Proが有効になります" });
    return;
  }
  if (code === PURCHASES_ERROR_CODE.PRODUCT_ALREADY_PURCHASED_ERROR) {
    showSnackbar({ type: "info", message: "既に購入済みです。「購入を復元」をお試しください" });
    return;
  }
  Sentry.captureException(error, { tags: { source: "revenue_cat_purchase" } });
  showSnackbar({ type: "error", message: "購入に失敗しました。時間を置いて再度お試しください" });
}
```

`PURCHASES_ERROR_CODE`は`react-native-purchases`からimport。

### 14. mobile-中: `customerInfoUpdateListener`が未登録

**方針**: 常設リスナーを追加

対象ファイル: `mobile/services/revenueCatService.ts`（新規export）、`mobile/app/_layout.tsx`（登録）

```ts
// services/revenueCatService.ts
export function addCustomerInfoUpdateListener(
  listener: (customerInfo: CustomerInfo) => void,
): () => void {
  Purchases.addCustomerInfoUpdateListener(listener);
  return () => Purchases.removeCustomerInfoUpdateListener(listener);
}

// app/_layout.tsx
useEffect(() => {
  const unsubscribe = addCustomerInfoUpdateListener(() => {
    queryClient.invalidateQueries({ queryKey: ["pro", "status"] });
  });
  return unsubscribe;
}, []);
```

### 15. mobile-中: プラットフォームをまたいだ解約導線の誤案内

**方針**: 今回は見送り。RevenueCat/Google Play側にAndroid向けPro商品が未設定で実害ユーザーがいないため、Android向けPro展開時に対応する。

### 16. 低優先度5件

**方針**: 簡単な2件のみ対応、残り3件は見送り

- 対応: `mobile/services/proService.ts:26` のコメントから issue 番号（`#318`）を削除
- 対応: `back/app/models/concerns/entitlement.rb` の練習メニュー上限コメントを実装値（3件、`PRACTICE_MENU_FREE_LIMIT`）に合わせて修正
- 見送り: 大規模テーブルへの非concurrentインデックス作成、`TrialExpiringBanner`の残日数境界値、テストの実装詳細依存・網羅性不足

## 未合意項目

(すべて合意完了)

---

## 全体まとめ・実装順序

1. **back** (`fix/450-pro-review-fixes`)
   - #1 ExpirationHandlerの順序逆転ガード + spec追加
   - #5 BaseHandlerに`with_lock`追加 + spec追加
   - #6 MatchResult#recalculate_activityをrescueで分離 + spec追加
   - #9 WebhookEvent.find_or_create_pending!のRecordNotUniqueをrescue + spec追加
   - #16 entitlement.rbのコメント修正
   - 検証: `docker compose exec back bundle exec rspec spec/services/revenue_cat/ spec/services/app/stripe/ spec/models/match_result_spec.rb`、`bundle exec rubocop`

2. **mobile** (`fix/450-pro-review-fixes`)
   - #2 PaywallModal.tsx / app/pro/index.tsx の handlePurchase 分離（購入成功≠同期成功）
   - #3 account/subscription/index.tsx の feature flag 分割代入修正 + テスト修正
   - #4 account/subscription/index.tsx に isError 分岐追加
   - #8 account-deletion.tsx に pro_active エラー専用ハンドリング追加
   - #11 PaywallModal.tsx / app/pro/index.tsx の handleRestore に entitlements.active 分岐追加
   - #12 handlePurchase / handleRestore に二重タップガード追加
   - #13 RevenueCatエラーコード（PAYMENT_PENDING_ERROR, PRODUCT_ALREADY_PURCHASED_ERROR）出し分け追加
   - #14 revenueCatService.ts に addCustomerInfoUpdateListener 追加、_layout.tsx に登録
   - #16 proService.ts のコメントからissue番号削除
   - 検証: `yarn lint`, `yarn typecheck`（`yarn test`はローカル実行せずCI任せ）

3. 完了後、back/mobileそれぞれコミット分割（指摘ごとに1コミット）、push、PR作成（base: release/pro-202605）

## 見送り項目（対応しない、理由付き）

- back-高2: v1 baseball_notes の `game_result_id` 消失 → front未使用のため実害なし
- back-高3: グループ招待リンクの1件上限 → mobile側は既にPaywallModalで対応済み
- back-中: Subscriptionバックフィルのrace → Postgres単一statement snapshotのため実質発生しない
- back-中: Web決済完了後のPro有効化監視なし → 運用監視は別issueで後日対応
- mobile-中: プラットフォームをまたいだ解約導線の誤案内 → Android向けPro商品が未設定で実害ユーザーなし
- 低優先度3件: 非concurrentインデックス、TrialExpiringBanner境界値、テスト網羅性不足 → 余裕があるときに対応

## 検証方法（各項目共通）

- back: 該当spec追加・修正後 `docker compose exec back bundle exec rspec <対象spec>`、`bundle exec rubocop`
- mobile: `yarn lint` / `yarn typecheck`（`yarn test`はCI任せ、ローカル実行しない）
