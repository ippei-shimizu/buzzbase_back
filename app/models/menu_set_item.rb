class MenuSetItem < ApplicationRecord
  belongs_to :menu_set
  belongs_to :practice_menu
end
