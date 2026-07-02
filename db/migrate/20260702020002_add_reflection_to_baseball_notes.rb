class AddReflectionToBaseballNotes < ActiveRecord::Migration[7.1]
  def change
    # 問い→回答の構造化データ。[{ "question": "...", "answer": "..." }]
    add_column :baseball_notes, :reflection_answers, :jsonb, null: false, default: []
    add_reference :baseball_notes, :reflection_template, null: true, foreign_key: true
  end
end
