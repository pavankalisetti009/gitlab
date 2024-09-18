# frozen_string_literal: true

# WARNING: Before you make a change to secrets.yml, read the development guide for GitLab secrets
# doc/development/application_secrets.md.
#
# This file needs to be loaded BEFORE any initializers that attempt to
# prepend modules that require access to secrets (e.g. EE's 0_as_concern.rb).
#
# Be sure to restart your server when you modify this file.

require 'securerandom'

def create_tokens
  # Inspired by https://github.com/rails/rails/blob/v7.0.8.4/railties/lib/rails/secrets.rb#L25-L36
  raw_secrets = begin
    YAML.safe_load(File.read(Rails.root.join('config/secrets.yml')))
  rescue Errno::ENOENT, Psych::SyntaxError
    {}
  end
  raw_secrets ||= {}

  secrets = {}
  secrets.merge!(raw_secrets["shared"].deep_symbolize_keys) if raw_secrets["shared"]
  secrets.merge!(raw_secrets[Rails.env].deep_symbolize_keys) if raw_secrets[Rails.env]

  # Copy secrets into credentials since Rails.application.secrets is populated from config/secrets.yml
  # Later, once config/secrets.yml won't be read automatically, we'll need to do it manually, and set
  secrets.each do |key, value|
    Rails.application.credentials[key] = value
  end

  # Historically, ENV['SECRET_KEY_BASE'] takes precedence over secrets.yml, so we maintain that
  # behavior by ensuring the environment variable always overrides secrets.yml.
  env_secret_key = ENV['SECRET_KEY_BASE']
  Rails.application.credentials.secret_key_base = env_secret_key if env_secret_key.present?

  defaults = {
    secret_key_base: generate_new_secure_token,
    otp_key_base: generate_new_secure_token,
    db_key_base: generate_new_secure_token,
    openid_connect_signing_key: generate_new_rsa_private_key
  }

  # encrypted_settings_key_base is optional for now
  if ENV['GITLAB_GENERATE_ENCRYPTED_SETTINGS_KEY_BASE']
    defaults[:encrypted_settings_key_base] =
      generate_new_secure_token
  end

  missing_secrets = set_missing_keys(defaults)
  write_secrets_yml(missing_secrets) unless missing_secrets.empty?
end

def generate_new_secure_token
  SecureRandom.hex(64)
end

def generate_new_rsa_private_key
  OpenSSL::PKey::RSA.new(2048).to_pem
end

def warn_missing_secret(secret)
  return if Rails.env.test?

  warn "Missing Rails.application.credentials.#{secret} for #{Rails.env} environment. The secret will be generated and stored in config/secrets.yml."
end

def set_missing_keys(defaults)
  defaults.stringify_keys.each_with_object({}) do |(key, default), missing|
    next if Rails.application.credentials.public_send(key).present?

    warn_missing_secret(key)
    missing[key] = Rails.application.credentials[key] = default
  end
end

def write_secrets_yml(missing_secrets)
  secrets_yml = Rails.root.join('config/secrets.yml')
  rails_env = Rails.env.to_s
  secrets = YAML.load_file(secrets_yml) if File.exist?(secrets_yml)
  secrets ||= {}
  secrets[rails_env] ||= {}

  secrets[rails_env].merge!(missing_secrets)
  File.write(secrets_yml, YAML.dump(secrets), mode: 'w', perm: 0o600)
end

create_tokens
