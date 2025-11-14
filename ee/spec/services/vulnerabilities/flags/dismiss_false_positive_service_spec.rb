# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Flags::DismissFalsePositiveService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:finding) { vulnerability.findings.first }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject(:service) { described_class.new(user, vulnerability) }

  describe '#execute' do
    context 'when user is authorized' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when creating a new flag' do
        let!(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            description: 'AI detected as false positive'
          )
        end

        it 'creates a new vulnerability flag with correct attributes' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).to be_persisted
          expect(flag.flag_type).to eq('false_positive')
          expect(flag.origin).to start_with('manual_')
          expect(flag.description).to eq('Manually dismissed as false positive')
          expect(flag.confidence_score).to eq(0.0)
          expect(flag.project_id).to eq(project.id)
          expect(flag.finding).to eq(finding)
        end
      end

      context 'when manual flag already exists' do
        let!(:existing_manual_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            description: 'Previous manual dismissal'
          )
        end

        let!(:ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            description: 'AI detection'
          )
        end

        it 'creates a new manual flag instead of updating existing one' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:is_new_flag]).to be true

          flag = result.payload[:flag]
          expect(flag).not_to eq(existing_manual_flag)
          expect(flag.confidence_score).to eq(0.0)
          expect(flag.origin).to start_with('manual_')
          expect(flag.description).to eq('Manually dismissed as false positive')
          expect(flag.project_id).to eq(project.id)

          # Verify existing flag is unchanged
          existing_manual_flag.reload
          expect(existing_manual_flag.description).to eq('Previous manual dismissal')
        end
      end

      context 'when flag has validation errors' do
        let!(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            description: 'AI detected as false positive'
          )
        end

        before do
          allow_next_instance_of(Vulnerabilities::Flag) do |flag|
            allow(flag).to receive_messages(save: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['Validation error']))
          end
        end

        it 'returns an error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Validation error')
        end
      end
    end

    context 'when user is not authorized' do
      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end
    end

    context 'when vulnerability is nil' do
      subject(:service) { described_class.new(user, nil) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Vulnerability not found')
      end
    end

    context 'when vulnerability has no finding' do
      let(:vulnerability_without_finding) { create(:vulnerability, project: project) }

      subject(:service) { described_class.new(user, vulnerability_without_finding) }

      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No current finding available')
      end
    end

    context 'when vulnerability has no flags' do
      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No vulnerability flag available to dismiss')
      end
    end

    context 'when latest vulnerability flag has confidence score of 0.0' do
      let!(:existing_flag_with_zero_confidence) do
        create(
          :vulnerabilities_flag,
          finding: finding,
          flag_type: :false_positive,
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.0,
          description: 'Already dismissed'
        )
      end

      before_all do
        project.add_maintainer(user)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('No vulnerability flag available to dismiss')
      end
    end

    context 'when latest vulnerability flag has confidence score greater than 0.0' do
      let!(:existing_flag_with_positive_confidence) do
        create(
          :vulnerabilities_flag,
          finding: finding,
          flag_type: :false_positive,
          origin: 'ai_sast_fp_detection',
          confidence_score: 0.8,
          description: 'AI detected as false positive'
        )
      end

      before_all do
        project.add_maintainer(user)
      end

      it 'successfully creates a new manual flag' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:is_new_flag]).to be true

        flag = result.payload[:flag]
        expect(flag).to be_persisted
        expect(flag.confidence_score).to eq(0.0)
        expect(flag.origin).to start_with('manual_')
      end
    end

    describe '#can_dismiss_flag?' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when finding has no flags' do
        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has confidence score of 0.0' do
        let!(:flag_with_zero_confidence) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0
          )
        end

        it 'returns false' do
          expect(service.send(:can_dismiss_flag?)).to be false
        end
      end

      context 'when latest flag has confidence score greater than 0.0' do
        let!(:flag_with_positive_confidence) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.7
          )
        end

        it 'returns true' do
          expect(service.send(:can_dismiss_flag?)).to be true
        end
      end

      context 'when there are multiple flags and latest has confidence score > 0.0' do
        let!(:older_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'manual',
            confidence_score: 0.0,
            created_at: 2.days.ago
          )
        end

        let!(:latest_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.9,
            created_at: 1.day.ago
          )
        end

        it 'returns true based on latest flag' do
          expect(service.send(:can_dismiss_flag?)).to be true
        end
      end
    end
  end

  describe 'private methods' do
    before_all do
      project.add_maintainer(user)
    end

    describe '#authorized?' do
      it 'returns true when user can admin vulnerability' do
        expect(service.send(:authorized?)).to be true
      end

      context 'when user cannot admin vulnerability' do
        let(:unauthorized_user) { create(:user) }

        subject(:service) { described_class.new(unauthorized_user, vulnerability) }

        it 'returns false' do
          expect(service.send(:authorized?)).to be false
        end
      end
    end

    describe '#current_finding' do
      it 'returns the last finding of the vulnerability' do
        expect(service.send(:current_finding)).to eq(finding)
      end
    end
  end
end
