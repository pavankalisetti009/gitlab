# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingTokenStatus, feature_category: :secret_detection do
  describe 'factory' do
    it 'creates a valid finding token status' do
      token_status = build(:finding_token_status)
      expect(token_status).to be_valid
    end

    it 'creates a finding token status with inactive status' do
      token_status = build(:finding_token_status, :inactive)
      expect(token_status).to be_valid
      expect(token_status.status_inactive?).to be true
    end

    it 'creates a finding token status with unknown status' do
      token_status = build(:finding_token_status, :unknown)
      expect(token_status).to be_valid
      expect(token_status.status_unknown?).to be true
    end
  end

  describe 'callbacks' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }

    context 'when project_id is nil' do
      it 'sets project_id from the finding before validation' do
        token_status = described_class.new(finding: finding, status: :active)

        expect(token_status.project_id).to be_nil

        token_status.validate

        expect(token_status.project_id).to eq(finding.project_id)
      end
    end

    context 'when project_id is already set' do
      it 'does not override project_id' do
        token_status = described_class.new(finding: finding, project_id: 9999, status: :active)

        token_status.validate

        expect(token_status.project_id).to eq(9999)
      end
    end
  end

  describe 'associations' do
    it 'belongs to a finding with the correct class name, foreign key, and inverse relation' do
      is_expected.to belong_to(:finding)
        .class_name('Vulnerabilities::Finding')
        .with_foreign_key('vulnerability_occurrence_id')
        .inverse_of(:finding_token_status)
    end

    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project_id) }
  end

  describe 'enums' do
    it 'defines the correct statuses' do
      expect(described_class.statuses).to eq({
        'unknown' => 0,
        'active' => 1,
        'inactive' => 2
      })
    end

    it 'supports _prefix for status enum' do
      status = described_class.new(status: :active)
      expect(status.status_active?).to be true
      expect(status.status_inactive?).to be false
    end
  end

  describe 'internal event tracking' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) do
      create(:vulnerabilities_finding, :with_secret_detection, project: project)
    end

    context 'on create' do
      it 'tracks event with active status' do
        expect { create(:finding_token_status, :active, finding: finding) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'active'
            }
          )
      end

      it 'tracks event with inactive status' do
        expect { create(:finding_token_status, :inactive, finding: finding) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'inactive'
            }
          )
      end
    end

    context 'on update' do
      let!(:token_status) { create(:finding_token_status, :unknown, finding: finding) }

      it 'tracks event when status changes from unknown to active' do
        expect { token_status.update!(status: :active) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'active'
            }
          )
      end

      it 'tracks event when status changes from unknown to inactive' do
        expect { token_status.update!(status: :inactive) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'inactive'
            }
          )
      end

      it 'tracks event when status changes from active to inactive' do
        token_status.update!(status: :active)

        expect { token_status.update!(status: :inactive) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'inactive'
            }
          )
      end

      it 'does not track event when status does not change' do
        expect { token_status.update!(last_verified_at: 1.hour.ago) }
          .not_to trigger_internal_events('secret_detection_token_verified')
      end
    end

    context 'when finding has no token_type' do
      before do
        allow(finding).to receive(:token_type).and_return(nil)
      end

      it 'does not track event on create' do
        expect { create(:finding_token_status, finding: finding) }
          .not_to trigger_internal_events('secret_detection_token_verified')
      end

      it 'does not track event on update' do
        token_status = create(:finding_token_status, :unknown, finding: finding)

        expect { token_status.update!(status: :active) }
          .not_to trigger_internal_events('secret_detection_token_verified')
      end
    end

    context 'when tracking fails' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:track_internal_event)
            .and_raise(StandardError, 'Tracking error')
        end
      end

      it 'tracks exception on create but does not raise' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(StandardError), hash_including(finding_id: finding.id))

        expect { create(:finding_token_status, finding: finding) }
          .not_to raise_error
      end

      it 'tracks exception on update but does not raise' do
        token_status = create(:finding_token_status, :unknown, finding: finding)

        allow(token_status).to receive(:track_internal_event)
          .and_raise(StandardError, 'Tracking error')

        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(StandardError), hash_including(finding_id: finding.id))

        expect { token_status.update!(status: :active) }
          .not_to raise_error
      end
    end
  end
end
