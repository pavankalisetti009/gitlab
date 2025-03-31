# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineCreation::StartPipelineService, feature_category: :continuous_integration do
  let(:pipeline) { build(:ci_pipeline) }

  subject(:service) { described_class.new(pipeline) }

  describe '#execute' do
    it 'calls the pipeline runners matching validation service' do
      expect(Ci::PipelineCreation::DropNotRunnableBuildsService)
        .to receive(:new)
        .with(pipeline)
        .and_return(double('service', execute: true))

      service.execute
    end

    context 'for secrets provider check' do
      context 'when the enable_secrets_provider_check_on_pre_assign_runner_checks feature flag is enabled' do
        it 'does not invoke the DropSecretsProviderNotFoundBuildsService' do
          allow_next_instance_of(Ci::PipelineCreation::DropSecretsProviderNotFoundBuildsService) do |instance|
            expect(instance).not_to receive(:execute)
          end

          service.execute
        end
      end

      context 'when the enable_secrets_provider_check_on_pre_assign_runner_checks feature flag is disabled' do
        before do
          stub_feature_flags(enable_secrets_provider_check_on_pre_assign_runner_checks: false)
        end

        it 'invokes the DropSecretsProviderNotFoundBuildsService' do
          allow_next_instance_of(Ci::PipelineCreation::DropSecretsProviderNotFoundBuildsService) do |instance|
            expect(instance).to receive(:execute)
          end

          service.execute
        end
      end
    end
  end
end
