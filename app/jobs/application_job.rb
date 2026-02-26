class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  rescue_from StandardError do |exception|
    if Sentry.initialized?
      Sentry.capture_exception(exception, extra: {
                                 job_class: self.class.name,
                                 job_id:
                               })
    end
    raise exception
  end
end
