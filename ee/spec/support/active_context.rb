# frozen_string_literal: true

RSpec.configure do |config|
  config.include ActiveContextHelpers, :active_context

  config.before(:all, :active_context) do
    # Clear adapter cache to ensure migrations use the current active connection.
    ActiveContext::Adapter.instance_variable_set(:@current, nil)
  end

  config.after(:all, :active_context) do
    delete_active_context_indices!
  end

  config.around(:each, :active_context) do |example|
    refresh_active_context_indices!

    example.run

    clear_active_context_data!
  end
end
