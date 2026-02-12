# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::SystemDefined::Definitions::Task, feature_category: :team_planning do
  describe '.filterable?' do
    it 'returns true' do
      expect(described_class.filterable?).to be(true)
    end

    it 'returns a boolean value' do
      expect(described_class.filterable?).to be_in([true, false])
    end
  end
end
