# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MutationType, feature_category: :api do
  describe 'deprecated mutations' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name, :reason, :milestone) do
      'ApiFuzzingCiConfigurationCreate' | 'The configuration snippet is now generated client-side' | '15.1'
    end

    with_them do
      let(:field) { get_field(field_name) }
      let(:deprecation_reason) { "#{reason}. Deprecated in #{milestone}." }

      it { expect(field).not_to be_present }
    end
  end

  def get_field(name)
    described_class.fields[GraphqlHelpers.fieldnamerize(name)]
  end

  describe '.authorization' do
    it 'allows ai_features and ai_workflows scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features, :ai_workflows)
    end
  end

  describe 'vulnerabilities revert to detected mutation scopes' do
    it 'includes api and ai_workflows scopes for vulnerabilities revert to detected mutation' do
      dismiss_mutation = described_class.fields['vulnerabilityRevertToDetected']
      expect(dismiss_mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
    end
  end

  describe 'vulnerabilities dismiss mutation scopes' do
    it 'includes api and ai_workflows scopes for vulnerabilities dismiss mutation' do
      dismiss_mutation = described_class.fields['vulnerabilityDismiss']
      expect(dismiss_mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
    end
  end

  describe 'vulnerabilities confirm mutation scopes' do
    it 'includes api and ai_workflows scopes for vulnerabilities confirm mutation' do
      confirm_mutation = described_class.fields['vulnerabilityConfirm']
      expect(confirm_mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
    end
  end

  describe 'vulnerabilities severity override mutation scopes' do
    it 'includes api and ai_workflows scopes for vulnerabilities bulk severity override mutation' do
      bulk_severity_override_mutation = described_class.fields['vulnerabilitiesSeverityOverride']
      scopes = bulk_severity_override_mutation.instance_variable_get(:@scopes)
      expect(scopes).to match_array([:api, :ai_workflows])
    end
  end

  describe 'vulnerability issue link create mutation scopes' do
    it 'includes api and ai_workflows scopes' do
      mutation = described_class.fields['vulnerabilityIssueLinkCreate']
      expect(mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
    end
  end
end
