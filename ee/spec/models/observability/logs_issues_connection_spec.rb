# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::LogsIssuesConnection, feature_category: :logging do
  describe 'associations' do
    it { is_expected.to belong_to(:issue).inverse_of(:observability_logs) }
  end

  describe '#populate_sharding_key' do
    it 'populating the project_id on save' do
      connection = create(:observability_logs_issues_connection, project_id: nil)

      expect(connection.project_id).to eq(connection.issue.project_id)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:issue_id) }

    it { is_expected.to validate_presence_of(:service_name) }
    it { is_expected.to validate_length_of(:service_name).is_at_most(500) }

    it { is_expected.to validate_presence_of(:severity_number) }

    it 'validates the value of severity_number is within 1..24' do
      is_expected.to validate_numericality_of(:severity_number)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(24)
    end

    it { is_expected.to validate_presence_of(:log_timestamp) }

    it { is_expected.to validate_presence_of(:trace_identifier) }
    it { is_expected.to validate_length_of(:trace_identifier).is_at_most(128) }

    it { is_expected.to validate_presence_of(:log_fingerprint) }
    it { is_expected.to validate_length_of(:log_fingerprint).is_at_most(128) }
  end

  it 'validates service_name cannot be empty when creating connection' do
    issue = create(:issue)
    connection = build(:observability_logs_issues_connection,
      service_name: '', # empty service name
      issue: issue
    )
    expect(connection).not_to be_valid
  end

  it 'validates connection associated to the linked issue' do
    connection = build(:observability_logs_issues_connection)
    expect(connection).not_to be_valid
    expect(connection.errors[:issue_id]).to eq(["can't be blank"])
  end
end
