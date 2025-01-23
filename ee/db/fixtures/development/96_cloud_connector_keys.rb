# frozen_string_literal: true

settings = Gitlab::CurrentSettings.current_application_settings

unless settings.cloud_connector_keys.present?
  puts Rainbow("Generate Cloud Connector signing keys").green
  settings.cloud_connector_keys = [OpenSSL::PKey::RSA.new(2048).to_pem]
  settings.save!
  puts Rainbow("\nOK").green
end
