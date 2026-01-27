# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanExecutionPolicy'], feature_category: :security_policy_management do
  let(:fields) { %i[description edit_path enabled name updated_at yaml policy_scope csp] }

  include_context 'with scan execution policy specific fields'

  it { expect(described_class).to have_graphql_fields(fields + type_specific_fields) }

  describe '#updated_at' do
    include GraphqlHelpers

    let(:policy_last_updated_at) { Time.current }
    let(:config) { instance_double(Security::OrchestrationPolicyConfiguration) }
    let(:policy_object) { { config: config } }

    before do
      allow(config).to receive(:policy_last_updated_at).and_return(policy_last_updated_at)
    end

    it 'resolves updated_at lazily from config' do
      result = resolve_field(:updated_at, policy_object, object_type: described_class)

      expect(result).to eq(policy_last_updated_at)
      expect(config).to have_received(:policy_last_updated_at)
    end

    context 'when config is nil' do
      let(:policy_object) { { config: nil } }

      it 'returns nil' do
        result = resolve_field(:updated_at, policy_object, object_type: described_class)

        expect(result).to be_nil
      end
    end
  end
end
