# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::MetricsIssuesConnection, feature_category: :metrics do
  describe 'associations' do
    it { is_expected.to belong_to(:issue).optional(false) }
  end

  describe '#populate_sharding_key' do
    it 'populating the namespace_id on save' do
      connection = create(:observability_metrics_issues_connection, namespace_id: nil)

      expect(connection.namespace_id).to eq(connection.issue.namespace_id)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:issue_id) }
    it { is_expected.to validate_presence_of(:metric_name) }
    it { is_expected.to validate_length_of(:metric_name).is_at_most(500) }
    it { is_expected.to validate_presence_of(:metric_type) }

    it 'validates uniqueness scoped to metric_type when issue is the same' do
      issue = create(:issue)
      create(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :gauge_type,
        issue: issue
      )
      duplicate = build_stubbed(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :gauge_type,
        issue: issue
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:metric_name]).to include(_('and metric_type combination must be unique per issue'))
    end

    it 'allows the same metric_name with different metric_type when issue is the same' do
      issue = create(:issue)
      create(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :gauge_type,
        issue: issue
      )
      different_type = build_stubbed(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :sum_type,
        issue: issue
      )
      expect(different_type).to be_valid
    end

    it 'allows the same metric_name with different metric_type when issue is different' do
      create(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :gauge_type
      )
      different_type = build_stubbed(:observability_metrics_issues_connection,
        metric_name: 'test_metric',
        metric_type: :sum_type
      )
      expect(different_type).to be_valid
    end
  end

  describe 'enum' do
    it do
      is_expected.to define_enum_for(:metric_type).with_values(
        gauge_type: 0,
        sum_type: 1,
        histogram_type: 2,
        exponential_histogram_type: 3
      )
    end
  end

  describe 'metric_type enum' do
    it 'allows setting and retrieving metric_type' do
      connection = create(:observability_metrics_issues_connection, metric_type: :gauge_type)
      expect(connection.gauge_type?).to be true
      expect(connection.metric_type).to eq('gauge_type')

      connection.sum_type!
      expect(connection.sum_type?).to be true
      expect(connection.metric_type).to eq('sum_type')
    end

    it 'raises an error for invalid metric_type' do
      expect { build(:observability_metrics_issues_connection, metric_type: :invalid_type) }
        .to raise_error(ArgumentError)
    end
  end
end
