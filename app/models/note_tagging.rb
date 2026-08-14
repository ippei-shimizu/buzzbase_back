class NoteTagging < ApplicationRecord
  belongs_to :baseball_note
  belongs_to :note_tag
end
