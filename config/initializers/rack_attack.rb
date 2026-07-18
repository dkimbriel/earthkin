# frozen_string_literal: true

# Rate limiting to blunt credential stuffing, password-reset abuse, and
# scripted hammering of the public enrollment/token endpoints. Throttle state
# lives in Rails.cache (per-dyno memory store), which is sufficient at this
# scale. Disabled in tests so request specs aren't throttled.
class Rack::Attack
  Rack::Attack.enabled = false if Rails.env.test?

  ### Throttles ###

  # Login attempts by IP.
  throttle('logins/ip', limit: 10, period: 60.seconds) do |req|
    req.ip if req.path == '/users/sign_in' && req.post?
  end

  # Login attempts by submitted email, so one IP can't spray many accounts.
  throttle('logins/email', limit: 5, period: 60.seconds) do |req|
    next unless req.path == '/users/sign_in' && req.post?

    email = begin
      req.params.dig('user', 'email')
    rescue StandardError
      nil
    end
    email.to_s.downcase.strip.presence
  end

  # Password-reset requests by IP.
  throttle('password_resets/ip', limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == '/users/password' && req.post?
  end

  # Public enrollment-application submissions by IP.
  throttle('applications/ip', limit: 20, period: 1.hour) do |req|
    req.ip if req.path == '/api/enrollment_applications' && req.post?
  end

  # Public token pages (payment-plan selection, meeting confirmation) by IP.
  throttle('public_tokens/ip', limit: 30, period: 60.seconds) do |req|
    req.ip if req.post? && (req.path.start_with?('/payment/') || req.path.start_with?('/meetings/'))
  end

  # Safety-net cap on total requests per IP.
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets', '/packs')
  end

  ### Response ###

  self.throttled_responder = lambda do |_request|
    [429, { 'Content-Type' => 'application/json' }, [{ error: 'Too many requests. Please slow down and try again shortly.' }.to_json]]
  end
end
