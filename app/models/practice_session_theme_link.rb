class PracticeSessionThemeLink < ApplicationRecord
  belongs_to :practice_session
  belongs_to :improvement_theme
end
