class ReflectionTemplate < ApplicationRecord
  # user_id が nil のものは運営提供プリセット。ユーザー自作は user に属する。
  belongs_to :user, optional: true

  validates :title, presence: true, length: { maximum: 50 }
  validate :questions_must_be_array_of_strings

  scope :presets, -> { where(is_preset: true) }
  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(sort_order: :asc, created_at: :asc) }

  after_save :unset_other_defaults, if: -> { is_default? && user_id.present? && saved_change_to_is_default? }

  # ユーザーに見せるテンプレ一覧。
  # - 本人の未アーカイブ自作テンプレ
  # - プリセットのうち、本人が編集コピー（origin_template_id で紐づく）を持たないもの
  # 編集で作られた新版は本人の自作として、旧版（archived）とコピー元プリセットは隠れる。
  # @param user [User]
  # @return [ActiveRecord::Relation]
  def self.available_for(user)
    own_active = where(user_id: user.id).active
    overridden_preset_ids = own_active.where.not(origin_template_id: nil).pluck(:origin_template_id)
    visible_presets = presets.where.not(id: overridden_preset_ids)
    where(id: own_active.ids + visible_presets.ids).ordered
  end

  # 編集を「新バージョンの作成」として扱う。原本(self)は更新せず、user 所有の新テンプレを作る。
  # 過去ノートが参照する原本を壊さないため、self が user の自作なら旧版として archive する
  # （プリセットは共有なので触らず、origin_template_id 経由で本人の一覧から隠す）。
  # @param user [User] 編集操作をするユーザー
  # @param params [ActionController::Parameters] title / questions を含む許可済みパラメータ
  # @return [ReflectionTemplate] 作成された新バージョン（save 失敗時は未保存インスタンス）
  def create_edited_version(user:, params:)
    new_version = user.reflection_templates.build(
      title: params[:title],
      questions: params[:questions],
      is_preset: false,
      is_default:,
      sort_order:,
      origin_template_id: origin_template_id || id
    )
    transaction do
      update!(archived_at: Time.current) if new_version.save && user_id == user.id
    end
    new_version
  end

  private

  # 同一ユーザーの既定テンプレは1つに保つ。
  def unset_other_defaults
    ReflectionTemplate.where(user_id:, is_default: true).where.not(id:).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
  end

  def questions_must_be_array_of_strings
    return if questions.is_a?(Array) && questions.all?(String)

    errors.add(:questions, 'は文字列の配列である必要があります')
  end
end
