# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ci::RunnerController, feature_category: :continuous_integration do
  let_it_be(:controller) { create(:ci_runner_controller, enabled: true) }

  subject(:entity) { described_class.new(controller).as_json }

  it 'includes basic fields' do
    is_expected.to include(
      id: controller.id,
      description: controller.description,
      enabled: controller.enabled,
      created_at: controller.created_at,
      updated_at: controller.updated_at
    )
  end

  it 'exposes the enabled field' do
    expect(entity[:enabled]).to be true
  end

  context 'when enabled is false' do
    let_it_be(:disabled_controller) { create(:ci_runner_controller, enabled: false) }

    subject(:entity) { described_class.new(disabled_controller).as_json }

    it 'exposes the enabled field as false' do
      expect(entity[:enabled]).to be false
    end
  end
end
