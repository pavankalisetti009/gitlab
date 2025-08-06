# frozen_string_literal: true

RSpec.shared_context 'with lightweight trial registration redesign turned on' do
  before do
    stub_experiments(lightweight_trial_registration_redesign: :candidate)
  end
end
