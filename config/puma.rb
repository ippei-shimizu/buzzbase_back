# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
#
worker_timeout 3600 if ENV.fetch('RAILS_ENV', 'development') == 'development'

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch('PORT') { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch('RAILS_ENV') { 'development' }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch('PIDFILE') { 'tmp/pids/server.pid' }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
# workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
# preload_app!

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Solid Queue の supervisor を Puma と同一プロセス内で起動し、別 worker dyno を持たずに
# ジョブを処理する（Rails 8 のデフォルト puma.rb と同じパターン）。
# test 以外はデフォルトで有効化する。明示的な opt-in（環境変数の設定漏れ）に頼ると、
# webhookや定期タスクが誰にも処理されずpendingのまま溜まり続ける不具合が起きうるため、
# 無効化したい場合だけ SOLID_QUEUE_IN_PUMA=false を設定する fail-safe な設計にしている。
# ENV の値は文字列のため、"false" / "0" もそのままでは truthy になってしまう点に注意し、
# ActiveModel::Type::Boolean で明示的にキャストする。
solid_queue_explicitly_disabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SOLID_QUEUE_IN_PUMA', nil)) == false
plugin :solid_queue unless Rails.env.test? || solid_queue_explicitly_disabled

# クラスタモード（workers指定）を将来有効化する場合、Solid Queue supervisorが
# workerプロセスごとに多重起動しないか要再確認（現状は単一プロセスのため未検証）。
