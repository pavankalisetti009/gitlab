# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flags::UpdateAiDetectionService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let(:params) do
    {
      confidence_score: 85,
      description: 'AI detected this as a false positive with high confidence'
    }
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:finding) { vulnerability.findings.first }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject(:service) { described_class.new(user, vulnerability, params) }

  describe '#execute' do
    context 'when user is authorized' do
      before_all do
        project.add_developer(user)
      end

      context 'when creating a new flag' do
        it 'creates a new vulnerability flag with correct attributes' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).to be_persisted
          expect(flag.flag_type).to eq('false_positive')
          expect(flag.origin).to eq('ai_sast_fp_detection')
          expect(flag.description).to eq('AI detected this as a false positive with high confidence')
          expect(flag.confidence_score).to eq(0.85)
          expect(flag.status).to eq('not_started')
          expect(flag.project_id).to eq(project.id)
          expect(flag.finding).to eq(finding)
        end

        it 'normalizes confidence score from 0-100 to 0.0-1.0' do
          result = service.execute

          expect(result).to be_success
          flag = result.payload[:flag]
          expect(flag.confidence_score).to eq(0.85)
        end

        context 'with edge case confidence scores' do
          it 'handles 0 confidence score' do
            params[:confidence_score] = 0
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.confidence_score).to eq(0.0)
          end

          it 'handles 100 confidence score' do
            params[:confidence_score] = 100
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.confidence_score).to eq(1.0)
          end
        end
      end

      context 'when updating an existing flag' do
        let!(:existing_flag) do
          create(:vulnerabilities_flag, :false_positive,
            finding: finding,
            origin: 'ai_sast_fp_detection',
            description: 'Old description',
            confidence_score: 0.5,
            status: :not_started
          )
        end

        it 'updates the existing flag' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be false

          flag = result.payload[:flag]
          expect(flag.id).to eq(existing_flag.id)
          expect(flag.description).to eq('AI detected this as a false positive with high confidence')
          expect(flag.confidence_score).to eq(0.85)
          expect(flag.status).to eq('not_started')
        end

        context 'when only confidence_score is provided' do
          let(:params) { { confidence_score: 95 } }

          it 'updates only the confidence_score and status' do
            result = service.execute

            expect(result).to be_success
            flag = result.payload[:flag]
            expect(flag.description).to eq('Old description')
            expect(flag.confidence_score).to eq(0.95)
            expect(flag.status).to eq('not_started')
          end
        end
      end

      context 'when vulnerability has multiple findings' do
        let!(:older_finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: project) }
        let!(:newer_finding) { create(:vulnerabilities_finding, vulnerability: vulnerability, project: project) }

        it 'uses the most recent finding' do
          result = service.execute

          expect(result).to be_success
          flag = result.payload[:flag]
          expect(flag.finding).to eq(newer_finding)
        end
      end

      context 'when flag validation fails' do
        it 'returns an error' do
          allow_next_instance_of(Vulnerabilities::Flag) do |flag|
            allow(flag).to receive_messages(
              save: false,
              errors: instance_double(
                ActiveModel::Errors,
                full_messages: ['Description is too long']
              )
            )
          end

          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Description is too long')
        end
      end
    end

    context 'when user is not authorized' do
      it 'returns an unauthorized error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end
    end

    context 'when vulnerability is nil' do
      subject(:service) { described_class.new(user, nil, params) }

      it 'returns a vulnerability not found error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Vulnerability not found')
      end
    end

    context 'when vulnerability has no findings' do
      let(:vulnerability_without_findings) { create(:vulnerability, project: project) }

      subject(:service) { described_class.new(user, vulnerability_without_findings, params) }

      before_all do
        project.add_developer(user)
      end

      it 'returns a no current finding error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No current finding available')
      end
    end

    context 'when confidence_score is nil' do
      let(:params) { { description: 'Test description' } }

      before_all do
        project.add_developer(user)
      end

      it 'handles nil confidence_score gracefully' do
        result = service.execute

        expect(result).to be_success
        flag = result.payload[:flag]
        expect(flag.confidence_score).to be(0.0)
      end
    end
  end
end
