module Api
  module V1
    class BaseballNotesController < ApplicationController
      # 過去に only: の指定漏れで未認証の create が 500 になったため、全アクションを
      # 認証必須にする。公開アクションを追加する場合のみ個別に検討する。
      before_action :authenticate_api_v1_user!
      before_action :set_baseball_note, only: %i[show update destroy]

      def index
        @baseball_notes = current_api_v1_user.baseball_notes.order(date: :desc)

        modified_notes = @baseball_notes.map do |note|
          memo_text = note.extract_and_truncate_memo
          note.as_json.merge('memo' => memo_text)
        end

        render json: modified_notes
      end

      def show
        render json: @baseball_note
      end

      def create
        @baseball_note = current_api_v1_user.baseball_notes.build(baseball_note_params)
        if @baseball_note.save
          render json: @baseball_note, status: :created
        else
          render json: @baseball_note.errros, status: :unprocessable_entity
        end
      end

      def update
        if @baseball_note.update(baseball_note_params)
          render json: @baseball_note
        else
          render json: @baseball_note.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @baseball_note.destroy
      end

      private

      def set_baseball_note
        @baseball_note = current_api_v1_user.baseball_notes.find(params[:id])
      end

      def baseball_note_params
        params.require(:baseball_note).permit(:title, :date, :memo)
      end
    end
  end
end
