# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::SystemDefined::WidgetDefinition, feature_category: :team_planning do
  describe '.widget_types' do
    subject(:widget_types) { described_class.widget_types }

    it 'includes all EE-specific widget types' do
      ee_widget_types = %w[
        health_status
        weight
        iteration
        progress
        verification_status
        requirement_legacy
        test_reports
        color
        status
        custom_fields
        vulnerabilities
      ]

      expect(widget_types).to include(*ee_widget_types)
    end
  end
end
