# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.1 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.1`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

# `regexp_xml_mini_backend` setting was removed in Rails 7.1.
# `XmlMini` doesn't use regular expressions anymore.

# Specify the format to use for cache entries. Using a newer format means that
# new cache entries will be incompatible with older versions of Rails.
# Rails.application.config.active_support.cache_format_version = 7.1

# Calculate the ETag for the response only after the response body is set.
# Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality = false

# When assigning to a collection of attachments, replace existing
# attachments instead of appending. Use #attach to add new attachments
# without replacement.
# Rails.application.config.active_storage.replace_on_assign_to_many = false

# Disable parameter wrapping for ActiveRecord models by default.
# Wrapped parameters are passed when the request's content type matches the
# wrap_parameters' format option (default: `json`).
# ActiveSupport.on_load(:action_controller) do
#   wrap_parameters format: []
# end

# Specifies whether `redirect_to` raises `ActionController::UnsafeRedirectError` for unsafe redirects.
# Rails.application.config.action_controller.raise_on_open_redirects = true

# Active Record Encryption now uses SHA-256 as its hash digest algorithm.
# Rails.application.config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256

# No longer run after_commit callbacks on the order they were defined
# (changed default in Rails 7.1).
# Rails.application.config.active_record.run_after_transaction_callbacks_in_order_defined = true

# Configures SQLite with a strict strings mode, which disables double-quoted string literals.
# Rails.application.config.active_record.sqlite3_adapter_strict_strings_by_default = true

# Set the Rails Regexp Timeout to limit the maximum time spent in regex matching to 1 second.
# Regexp.timeout = 1

# Enable raising on assignment to attr_readonly attributes.
# Rails.application.config.active_record.raise_on_assign_to_attr_readonly = true

# Enable validating only parents by default for `validate_associated_records_for_*` methods.
# Rails.application.config.active_record.automatic_scope_inversing = true

# Behavior of not_in predicate for nil values. When true, NOT IN clauses
# include records with NULL values.
# Rails.application.config.active_record.allow_deprecated_singular_associations_name = false

# Configures the ActiveSupport::MessageEncryptor to use AES-GCM-SIV encryption.
# Rails.application.config.active_support.message_serializer = :json_allow_marshal

# Set `expect` for filtering ActionController::Parameters.
# Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality = false

# Use sha256 as the default hashing method for `ActiveSupport::Digest`.
# Rails.application.config.active_support.hash_digest_class = OpenSSL::Digest::SHA256

# Set view rendering strategy. (`:deferred` works for streaming responses)
# Rails.application.config.action_view.preload_links_header = true

# Use an empty array as the default value for `ActionController::Parameters#each_pair`.
# Rails.application.config.action_controller.wrap_parameters_by_default = false

# Specifies if an `ActiveSupport::Cache::Store` will hash keys longer than 64 bytes.
# Rails.application.config.active_support.cache_format_version = 7.1
