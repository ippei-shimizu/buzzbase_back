class GroupInviteLink < ApplicationRecord
  AMBIGUOUS_CHARS = %w[0 O 1 I L].freeze
  CODE_LENGTH = 8

  belongs_to :group
  belongs_to :inviter, class_name: 'User'

  validates :code, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }

  before_validation :set_code, on: :create

  private

  def set_code
    self.code ||= generate_unique_code
  end

  def generate_unique_code
    loop do
      chars = SecureRandom.alphanumeric(CODE_LENGTH * 2).upcase.chars.reject { |c| AMBIGUOUS_CHARS.include?(c) }
      next if chars.length < CODE_LENGTH

      candidate = chars.first(CODE_LENGTH).join
      break candidate unless self.class.exists?(code: candidate)
    end
  end
end
