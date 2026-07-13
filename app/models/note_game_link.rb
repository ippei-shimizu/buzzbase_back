class NoteGameLink < ApplicationRecord
  belongs_to :baseball_note
  belongs_to :game_result
end
