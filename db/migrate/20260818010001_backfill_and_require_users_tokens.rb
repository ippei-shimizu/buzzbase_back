class BackfillAndRequireUsersTokens < ActiveRecord::Migration[7.1]
  # devise_token_auth は tokens を Hash 前提で in-place 更新するため、NULL のままだと
  # ログイン・トークン検証が NoMethodError で 500 になる。既存の NULL を空ハッシュへ寄せ、
  # 以降 NULL が入り込まないことを DB 側で保証する。
  def up
    # SET NOT NULL は ACCESS EXCLUSIVE を取るため、ロック待ちが長引いたらリリースごと失敗させる
    execute "SET LOCAL lock_timeout = '5s'"

    # json カラムでは SQL の NULL と JSON の null リテラルが別物で、後者は NOT NULL 制約も
    # すり抜けるため、どちらも空ハッシュへ寄せる
    execute "UPDATE users SET tokens = '{}' WHERE tokens IS NULL OR tokens::text = 'null'"
    change_column_default :users, :tokens, from: nil, to: {}
    change_column_null :users, :tokens, false
  end

  def down
    execute "SET LOCAL lock_timeout = '5s'"

    change_column_null :users, :tokens, true
    change_column_default :users, :tokens, from: {}, to: nil
  end
end
