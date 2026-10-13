require "jwt"

module Privacy
  class Token
    AUDIENCE = "cdn"
    JWKS_URL = "https://yeet.hackclub.com/.well-known/jwks.json"
    MUTEX = Mutex.new

    class << self
      def verify!(authorization, action)
        token = authorization.to_s.match(/\ABearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\z/i)&.captures&.first
        invalid! unless token && token.bytesize <= 16_384
        _, header = JWT.decode(token, nil, false)
        invalid! unless header["alg"] == "ES256" && header["typ"] == "JWT" && text?(header["kid"])
        invalid! if header.key?("crit")

        claims, = JWT.decode(token, key_for(header["kid"]), true,
          algorithms: [ "ES256" ], verify_iss: true, iss: "hackclub-privacy",
          verify_aud: true, aud: AUDIENCE, leeway: 30,
          required_claims: %w[iss aud iat exp jti request_id action dry_run subject])
        validate!(claims)
        raise Error.new("action_mismatch", 400) unless claims["action"] == action
        claims
      rescue JWT::DecodeError, ArgumentError, TypeError
        invalid!
      end

      private

      def validate!(claims)
        now = Time.now.to_i
        iat, exp = claims.values_at("iat", "exp")
        invalid! unless claims["aud"] == AUDIENCE && iat.is_a?(Integer) && exp.is_a?(Integer)
        invalid! unless exp > iat && exp - iat <= 300 && iat <= now + 30 && iat >= now - 330 && exp > now - 30
        invalid! unless text?(claims["jti"]) && text?(claims["request_id"])
        invalid! unless [ true, false ].include?(claims["dry_run"])
        subject = claims["subject"]
        invalid! unless subject.is_a?(Hash) && subject["emails"].is_a?(Array) && subject["emails"].size <= 100
        invalid! unless subject["emails"].all? { |email| text?(email) }
        %w[slack_id identity_id].each { |key| invalid! unless subject[key].nil? || text?(subject[key]) }
      end

      def text?(value)
        value.is_a?(String) && value.present? && value.bytesize <= 512 && !value.match?(/[[:cntrl:]]/)
      end

      def invalid!
        raise Error.new("invalid_token", 401)
      end

      def key_for(kid)
        MUTEX.synchronize do
          url = ENV.fetch("PRIVACY_JWKS_URL", JWKS_URL)
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if @url != url
            @url, @keys, @attempted_at, @fetched_at = url, nil, nil, nil
          end
          expired = !@keys || now - @fetched_at >= 300
          unknown = @keys && !@keys.key?(kid)
          if expired || unknown
            if @attempted_at && now - @attempted_at < 30
              raise Error.new("jwks_unavailable", 503) if expired
            else
              @attempted_at = now
              @keys = fetch_keys(url)
              @fetched_at = now
            end
          end
          @keys.fetch(kid) { invalid! }
        end
      end

      def fetch_keys(url)
        response = Faraday.get(url) do |req|
          req.options.open_timeout = 2
          req.options.timeout = 3
        end
        raise Error.new("jwks_unavailable", 503) unless response.success?
        document = JSON.parse(response.body)
        raise Error.new("jwks_unavailable", 503) unless document.is_a?(Hash) && document["keys"].is_a?(Array)
        keys = {}
        document["keys"].each do |jwk|
          next unless jwk.is_a?(Hash) && jwk["kty"] == "EC" && jwk["crv"] == "P-256"
          next unless text?(jwk["kid"]) && [ nil, "ES256" ].include?(jwk["alg"]) && [ nil, "sig" ].include?(jwk["use"])
          next if jwk.key?("key_ops") && !jwk["key_ops"].include?("verify")
          raise Error.new("jwks_unavailable", 503) if keys.key?(jwk["kid"])
          keys[jwk["kid"]] = JWT::JWK.import(jwk).verify_key
        end
        raise Error.new("jwks_unavailable", 503) if keys.empty?
        keys
      rescue Faraday::Error, JSON::ParserError, JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError, NoMethodError
        raise Error.new("jwks_unavailable", 503)
      end
    end
  end
end
