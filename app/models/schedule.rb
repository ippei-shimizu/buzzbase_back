class Schedule < ApplicationRecord
  EVENT_TYPES = %w[self_practice practice game other].freeze

  belongs_to :user
  belongs_to :menu_set, optional: true
  belongs_to :game_result, optional: true
  has_many :schedule_menus, -> { order(:sort_order) }, dependent: :destroy, inverse_of: :schedule
  has_many :practice_menus, through: :schedule_menus
  # チェック（済トグル）で作られた練習ログは実績のため、予定を消しても残して紐付けだけ外す。
  has_many :practice_logs, dependent: :nullify

  validates :title, length: { maximum: 50 }, allow_blank: true
  validates :title, presence: true, if: -> { menu_set_id.blank? }
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validate :exactly_one_of_recurrence_or_date

  scope :active, -> { where(active: true) }
  scope :recurring, -> { where.not(days_of_week: nil) }
  scope :single, -> { where.not(planned_on: nil) }

  # "1,3,5" を整数配列に変換する（月=1〜日=7）。
  # @return [Array<Integer>]
  def day_numbers
    days_of_week.to_s.split(',').map(&:to_i)
  end

  # 繰り返し（曜日固定）割り当てか。単発は false。
  # @return [Boolean]
  def recurring?
    days_of_week.present?
  end

  # 表示用タイトル。未設定時はメニューセット名にフォールバックする。
  # @return [String, nil]
  def display_title
    title.presence || menu_set&.name
  end

  # 予定に含まれるメニュー項目を解決する。メニューセットがあればその items、
  # 無ければ schedule_menus を使う。返却形式は表示・当日展開で共通。
  # @return [Array<Hash>]
  def resolved_menu_items
    source = menu_set ? menu_set.menu_set_items : schedule_menus
    source.map do |item|
      practice_menu = item.practice_menu
      {
        practice_menu_id: item.practice_menu_id,
        name: practice_menu&.name,
        unit_label: practice_menu&.unit_label,
        target_value: item.target_value,
        sort_order: item.sort_order
      }
    end
  end

  private

  # 繰り返し（days_of_week）と単発（planned_on）はどちらか一方のみ指定できる。
  def exactly_one_of_recurrence_or_date
    if days_of_week.blank? && planned_on.blank?
      errors.add(:base, '曜日または日付のいずれかを指定してください')
    elsif days_of_week.present? && planned_on.present?
      errors.add(:base, '曜日と日付は同時に指定できません')
    end
  end
end
