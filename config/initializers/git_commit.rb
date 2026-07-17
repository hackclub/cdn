# frozen_string_literal: true

GIT_COMMIT_SHA = begin
  sha = ENV["SOURCE_COMMIT"].presence
  sha = nil if sha == "unknown"

  if sha.nil?
    revision_file = Rails.root.join("REVISION")
    if revision_file.file?
      from_file = revision_file.read.strip.presence
      sha = from_file unless from_file.nil? || from_file == "unknown"
    end
  end

  sha.presence || (Rails.env.local? ? "dev" : "unknown")
end.freeze
