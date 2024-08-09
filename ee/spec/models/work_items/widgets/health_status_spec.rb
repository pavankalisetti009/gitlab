# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::HealthStatus, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item, :objective, health_status: :on_track) }

  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to include(:health_status) }
  end

  describe '#health_status' do
    subject { described_class.new(work_item).health_status }

    it { is_expected.to eq(work_item.health_status) }
  end

  describe '#rolled_up_health_status' do
    subject { described_class.new(work_item).rolled_up_health_status }

    it 'returns placeholder data' do
      is_expected.to contain_exactly(
        {
          health_status: "on_track",
          count: 0
        },
        {
          health_status: "needs_attention",
          count: 0
        },
        {
          health_status: "at_risk",
          count: 0
        }
      )
    end
  end
end
