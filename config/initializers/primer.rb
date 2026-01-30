# frozen_string_literal: true

# Disable the gem's automatic JS inclusion - we import it manually via Vite
# from the @primer/view-components npm package to avoid duplicate custom element registration
Primer::ViewComponents.configure do |config|
  config.silence_deprecations = true
end
