# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::Transition, feature_category: :team_planning do
  describe 'associations' do
    it { is_expected.to belong_to(:promoted_to_epic).class_name('Epic') }
  end
end
