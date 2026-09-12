class NoteThemeLink < ApplicationRecord
  belongs_to :baseball_note
  belongs_to :improvement_theme
end
