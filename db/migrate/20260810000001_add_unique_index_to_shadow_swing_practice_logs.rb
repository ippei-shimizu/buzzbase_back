class AddUniqueIndexToShadowSwingPracticeLogs < ActiveRecord::Migration[7.1]
  # shadow_swing 由来のログは同日1レコードへ集約する設計だが、DB制約が無く
  # 初回セッションの同時完了で重複行がサイレントに作られうる。source ごとに
  # 集約単位が異なる（manual は同日複数メニューを許容）ため、部分インデックスで
  # shadow_swing のみ (user_id, logged_on) を一意にする。
  def change
    add_index :practice_logs, %i[user_id logged_on],
              unique: true,
              where: "source = 'shadow_swing'",
              name: 'index_practice_logs_on_user_logged_on_shadow_swing'
  end
end
