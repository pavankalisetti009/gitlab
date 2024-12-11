# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::RegisterRunnerService, '#execute', :freeze_time, feature_category: :fleet_visibility do
  let(:registration_token) { 'abcdefg123456' }
  let(:token) {}
  let(:audit_service) { instance_double(::AuditEvents::RunnerAuditEventService) }
  let(:runner) { execute.payload[:runner] }
  let(:common_kwargs) do
    {
      name: 'ci_runner_registered',
      message: s_('Runners|Registered %{runner_type} CI runner'),
      token_field: :runner_registration_token
    }
  end

  before do
    stub_application_setting(runners_registration_token: registration_token)
    stub_application_setting(valid_runner_registrars: ApplicationSetting::VALID_RUNNER_REGISTRAR_TYPES)
    stub_application_setting(allow_runner_registration_token: true)
  end

  subject(:execute) { described_class.new(token, {}).execute }

  RSpec::Matchers.define :last_ci_runner do
    match { |runner| runner == ::Ci::Runner.last }
  end

  RSpec::Matchers.define :a_ci_runner_with_errors do
    match { |runner| runner.errors.any? }
  end

  shared_examples 'a service logging a runner registration audit event' do
    it 'returns newly-created runner' do
      expect(::AuditEvents::RunnerAuditEventService).to receive(:new)
        .with(last_ci_runner, token, token_scope, **common_kwargs)
        .and_return(audit_service)
      expect(audit_service).to receive(:track_event).once

      expect(execute).to be_success

      expect(runner).to eq(::Ci::Runner.last)
    end
  end

  context 'with a registration token' do
    let(:token) { registration_token }
    let(:token_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    it_behaves_like 'a service logging a runner registration audit event'
  end

  context 'when project token is used' do
    let_it_be(:project) { create(:project, :allow_runner_registration_token) }

    let(:token) { project.runners_token }
    let(:token_scope) { project }

    it_behaves_like 'a service logging a runner registration audit event'
  end

  context 'when group token is used' do
    let_it_be_with_reload(:group) { create(:group, :allow_runner_registration_token) }

    let(:token) { group.runners_token }
    let(:token_scope) { group }

    it_behaves_like 'a service logging a runner registration audit event'
  end
end
