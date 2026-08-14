module MediaAttachments
  # R2オブジェクトキーから公開URLを組み立てる。r2_key自体はフルURLを持たないため、
  # CDNドメイン変更時にこのモジュールの変更のみで済むようにする。
  module PublicUrlBuilder
    module_function

    def for(key)
      return nil if key.blank?

      "#{ENV.fetch('R2_PUBLIC_BASE_URL')}/#{key}"
    end
  end
end
