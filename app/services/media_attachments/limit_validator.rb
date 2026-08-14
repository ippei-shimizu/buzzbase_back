module MediaAttachments
  # クライアント側のチェックはバイパス可能なため、アップロード完了通知時にサーバー側でも
  # 無料/Pro上限（動画長さ・解像度、画像サイズ）を再検証する。
  class LimitValidator
    FREE_VIDEO_MAX_DURATION = 30
    PRO_VIDEO_MAX_DURATION = 180
    FREE_VIDEO_MAX_HEIGHT = 480
    # クライアントは長辺基準で縮小するため、縦持ち動画は長辺がそのまま height になる。
    # モバイル側の PRO_VIDEO_MAX_HEIGHT と揃えておかないと縦動画だけ弾かれる。
    PRO_VIDEO_MAX_HEIGHT = 1280
    FREE_IMAGE_MAX_BYTES = 5.megabytes
    PRO_IMAGE_MAX_BYTES = 10.megabytes

    def initialize(user:, attachment:)
      @user = user
      @attachment = attachment
    end

    # @return [Boolean]
    def valid?
      pro = @user.has_entitlement?('unlimited_media_uploads')
      @attachment.video? ? valid_video?(pro) : valid_image?(pro)
    end

    private

    def valid_video?(pro)
      @attachment.duration_seconds.to_i <= (pro ? PRO_VIDEO_MAX_DURATION : FREE_VIDEO_MAX_DURATION) &&
        long_edge <= (pro ? PRO_VIDEO_MAX_HEIGHT : FREE_VIDEO_MAX_HEIGHT)
    end

    def valid_image?(pro)
      @attachment.file_size_bytes.to_i <= (pro ? PRO_IMAGE_MAX_BYTES : FREE_IMAGE_MAX_BYTES)
    end

    # モバイル側は縦横どちらでも長辺基準で圧縮するため、height だけを見ると
    # 横持ち動画（長辺 = width）の検証をすり抜けてしまう。
    def long_edge
      [@attachment.width.to_i, @attachment.height.to_i].max
    end
  end
end
