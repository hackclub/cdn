# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = Rails.application.routes.default_url_options
  Rails.application.config.active_storage.content_types_to_serve_as_binary = []
  Rails.application.config.active_storage.content_types_allowed_inline = Hash.new.tap do |h|
    def h.include?(item) = true
  end
end
