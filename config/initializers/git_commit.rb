GIT_COMMIT_SHA = ENV.fetch("GIT_COMMIT_SHA") do
  `git rev-parse HEAD 2>/dev/null`.strip.presence || "dev"
end.freeze
