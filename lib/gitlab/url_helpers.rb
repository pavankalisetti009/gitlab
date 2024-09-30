# frozen_string_literal: true

module Gitlab
  class UrlHelpers
    WSS_PROTOCOL = "wss"

    def self.as_wss(url)
      return unless url.present?

      URI.parse(url).tap do |uri|
        uri.scheme = WSS_PROTOCOL
      end.to_s
    rescue URI::InvalidURIError
      nil
    end

    # Returns hostname of a URL with port.
    #
    # Examples:
    # - "ftp://example.com/dir" => "ftp://example.com:21"
    # - "http://username:password@gdk.test:3000/dir" => "http://gdk.test:3000"
    def self.normalized_base_url(url)
      parsed = Addressable::URI.parse(url)

      format("%{scheme}://%{host}:%{port}", scheme: parsed.scheme, host: parsed.host, port: parsed.inferred_port)
    end
  end
end
