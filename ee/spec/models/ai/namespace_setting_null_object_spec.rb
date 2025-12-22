# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::NamespaceSettingNullObject, feature_category: :ai_abstraction_layer do
  subject(:null_object) { described_class.new }

  describe '#duo_agent_platform_enabled' do
    it 'returns true' do
      expect(null_object.duo_agent_platform_enabled).to be true
    end
  end

  describe '#foundational_agents_default_enabled' do
    it 'returns true' do
      expect(null_object.foundational_agents_default_enabled).to be true
    end
  end
end
