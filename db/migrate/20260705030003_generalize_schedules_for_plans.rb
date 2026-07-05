class GeneralizeSchedulesForPlans < ActiveRecord::Migration[7.1]
  def change
    # 曜日固定の単一モデルから「繰り返し（days_of_week）」と「単発（planned_on）」の
    # 両対応へ一般化する。どちらか一方を必須とする排他制約はモデル層で担保する。
    change_column_null :schedules, :days_of_week, true
    change_column_null :schedules, :scheduled_time, true
    change_column_null :schedules, :title, true

    add_column :schedules, :planned_on, :date
    add_column :schedules, :event_type, :string, null: false, default: 'self_practice'
    add_reference :schedules, :menu_set, foreign_key: true, null: true
    add_reference :schedules, :game_result, foreign_key: true, null: true

    add_index :schedules, %i[user_id planned_on]
  end
end
