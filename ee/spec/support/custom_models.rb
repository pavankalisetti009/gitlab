# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, :requires_custom_models_setup) do |example|
    ai_gateway_url = Ai::Setting.instance.ai_gateway_url
    litellm_proxy_url = ENV['LITELLM_PROXY_URL']

    skip_reason = <<~REASON
      Skipping '#{example.metadata[:description]}' because it is a custom models test,
      and requires both Ai::Setting.instance.ai_gateway_url and ENV['LITELLM_PROXY_URL'] to be set.

      In local development environment, you can set these variables by running:

      `export LITELLM_PROXY_URL=http://localhost:4000`

      and, in a Rails console:

      `Ai::Setting.instance.update!(ai_gateway_url: 'http://localhost:5052')`
    REASON

    skip(skip_reason) if ai_gateway_url.blank? || litellm_proxy_url.blank?
  end

  config.around(:each, :requires_custom_models_setup) do |example|
    with_net_connect_allowed do
      example.run
    end
  end
end
