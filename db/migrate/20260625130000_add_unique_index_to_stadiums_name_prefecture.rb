class AddUniqueIndexToStadiumsNamePrefecture < ActiveRecord::Migration[7.1]
  def change
    # Stadium#name の一意性は Rails バリデーション（scope: :prefecture_id）だけでは
    # 並行リクエストで突破され得る。prefecture_id がある球場は DB の部分 UNIQUE で
    # 重複登録を防ぐ。prefecture_id が NULL のデータは従来どおり重複を許容する。
    add_index :stadiums, %i[name prefecture_id],
              unique: true, where: 'prefecture_id IS NOT NULL',
              name: 'index_stadiums_on_name_prefecture_id_not_null'
  end
end
