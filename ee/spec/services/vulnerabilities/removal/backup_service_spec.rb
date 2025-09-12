# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Removal::BackupService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:backup_model) { Vulnerabilities::Backups::Vulnerability }
    let(:backup_date) { Time.zone.today }
    let(:deleted_rows) { [:foo] }

    subject(:execute) { described_class.execute(backup_model, backup_date, deleted_rows) }

    it 'instantiates a service object and sends execute message to it' do
      expect_next_instance_of(described_class, backup_model, backup_date, deleted_rows) do |service_object|
        expect(service_object).to receive(:execute)
      end

      execute
    end
  end

  describe '#execute' do
    shared_examples_for 'creating backup for' do |backup_model, factory:|
      let(:backup_date) { Time.zone.today }
      let(:original_record) { create(*factory).reload } # rubocop:disable Rails/SaveBang -- This is factory bot `create`.
      let(:deleted_rows) { original_record.class.where(id: original_record).delete_all_returning }
      let(:service_object) { described_class.new(backup_model, backup_date, deleted_rows) }

      subject(:backup!) { service_object.execute }

      it 'creates a new record in the database' do
        expect { backup! }.to change { backup_model.count }.by(1)
      end

      it 'assigns attributes correctly' do
        backup!

        backup_record = backup_model.last

        data_properties(backup_model).each do |column|
          validate_data_consistency(backup_record, original_record, column)
        end

        expect(backup_model.last).to have_attributes(
          original_record_identifier: original_record.id,
          date: backup_date,
          **mapped_columns(backup_model, original_record),
          project_id: original_record.project_id
        )
      end

      def validate_data_consistency(backup_record, original_record, column)
        original_value = prepare_value_for_comparison(original_record, column)

        expect(backup_record.original_data[column]).to eq(original_value)
      end

      def prepare_value_for_comparison(original_record, column)
        attribute_type = original_record.class.attribute_types[column]

        case attribute_type
        when ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter
          original_record[column]&.floor(3)
        when ActiveRecord::Enum::EnumType
          original_record.read_attribute_before_type_cast(column)&.to_i
        when Gitlab::Database::ShaAttribute
          original_record.read_attribute_for_database(column).to_s
        else
          original_record[column]
        end
      end

      def data_properties(backup_model)
        ignored_columns = ['id', *backup_model.column_mappings.keys.map(&:to_s)]

        backup_model.original_model.column_names - ignored_columns
      end

      def mapped_columns(backup_model, original_record)
        backup_model.column_mappings.each_with_object({}) do |(original_column_name, new_column_name), memo|
          memo[new_column_name] = original_record[original_column_name]
        end
      end
    end

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::Finding,
      factory: [:vulnerabilities_finding, :detected]

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingEvidence,
      factory: :vulnerabilties_finding_evidence

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingFlag,
      factory: :vulnerabilities_flag

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingIdentifier,
      factory: :vulnerabilities_finding_identifier

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingLink,
      factory: :finding_link

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingRemediation,
      factory: :vulnerability_finding_remediation

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::FindingSignature,
      factory: :vulnerabilities_finding_signature

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::Vulnerability,
      factory: :vulnerability

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilityExternalIssueLink,
      factory: :vulnerabilities_external_issue_link

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilityIssueLink,
      factory: :vulnerabilities_issue_link

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilityMergeRequestLink,
      factory: :vulnerabilities_merge_request_link

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilitySeverityOverride,
      factory: :vulnerability_severity_override

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilityStateTransition,
      factory: :vulnerability_state_transition

    it_behaves_like 'creating backup for',
      Vulnerabilities::Backups::VulnerabilityUserMention,
      factory: :vulnerability_user_mention
  end
end
