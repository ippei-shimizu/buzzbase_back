module Api
  module V1
    module Pro
      # POST /api/v1/pro/cancellation_feedbacks
      # 解約直後の引き止めモーダル後のアンケート回答を保存する。
      # Flipper :cancellation_survey で機能フラグ制御（無効時はエンドポイント自体を隠す）。
      class CancellationFeedbacksController < ApplicationController
        before_action :authenticate_api_v1_user!

        def create
          return head :not_found unless Flipper.enabled?(:cancellation_survey, current_api_v1_user)

          # enum 範囲外の値は build 時に ArgumentError を投げるため、事前にホワイトリストで弾いて
          # 422 invalid_reason に揃える。nil / blank は通常の presence バリデーションに任せる。
          reason = feedback_params[:reason]
          if reason.present? && CancellationFeedback::REASONS.exclude?(reason)
            return render json: { error: 'invalid_reason' }, status: :unprocessable_entity
          end

          feedback = current_api_v1_user.cancellation_feedbacks.build(
            subscription: current_api_v1_user.subscription,
            **feedback_params.to_h.symbolize_keys
          )

          if feedback.save
            render json: { id: feedback.id }, status: :created
          else
            render json: { error: error_code_for(feedback) }, status: :unprocessable_entity
          end
        end

        private

        def feedback_params
          params.permit(:reason, :note)
        end

        # クライアントへ「何が原因で失敗したか」をシンプルなコード文字列で返す。
        # i18n 化されたエラーメッセージに依存せず、属性値で reason の状態を判定する。
        def error_code_for(feedback)
          if feedback.errors[:reason].any?
            return feedback.reason.blank? ? 'reason_required' : 'invalid_reason'
          end
          return 'note_too_long' if feedback.errors[:note].any?

          'invalid'
        end
      end
    end
  end
end
