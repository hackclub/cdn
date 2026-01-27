Rails.application.config.hack_club_auth = ActiveSupport::OrderedOptions.new
Rails.application.config.hack_club_auth.client_id = ENV.fetch("HACKCLUB_CLIENT_ID", nil)
Rails.application.config.hack_club_auth.client_secret = ENV.fetch("HACKCLUB_CLIENT_SECRET", nil)
Rails.application.config.hack_club_auth.base_url = ENV.fetch("HACKCLUB_AUTH_URL") { Rails.env.production? ? "https://auth.hackclub.com" : "https://hca.dinosaurbbq.org" }
