# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfileType, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :name,
      :description,
      :scan_type,
      :gitlab_recommended,
      :created_at,
      :updated_at
    )
  end

  it { expect(described_class.graphql_name).to eq('ScanProfileType') }

  describe 'fields' do
    it { expect(described_class).to have_graphql_field(:id, resolver_method: :resolve_id) }
    it { expect(described_class).to have_graphql_field(:name) }
    it { expect(described_class).to have_graphql_field(:description) }
    it { expect(described_class).to have_graphql_field(:scan_type) }
    it { expect(described_class).to have_graphql_field(:gitlab_recommended) }
    it { expect(described_class).to have_graphql_field(:created_at) }
    it { expect(described_class).to have_graphql_field(:updated_at) }
  end

  describe '#resolve_id' do
    let_it_be(:current_user) { create(:user) }

    subject(:resolved_id) { resolve_field(:id, scan_profile, current_user: current_user) }

    context 'when scan profile is persisted' do
      let(:scan_profile) { create(:security_scan_profile) }

      it 'returns the global ID' do
        expect(resolved_id).to eq(scan_profile.to_global_id)
      end

      it 'returns a GlobalID instance' do
        expect(resolved_id).to be_a(GlobalID)
      end

      it 'uses the database ID' do
        expect(resolved_id.model_id).to eq(scan_profile.id.to_s)
      end
    end

    context 'when scan profile is not persisted' do
      let(:scan_profile) do
        build(:security_scan_profile, scan_type: :secret_detection)
      end

      subject(:resolved_id) do
        type_instance = described_class.allocate
        type_instance.instance_variable_set(:@object, scan_profile)
        type_instance.resolve_id
      end

      it 'builds a URI::GID using scan_type' do
        expect(scan_profile.persisted?).to be_falsey
        expect(resolved_id).to be_a(URI::GID)
      end

      it 'uses scan_type as the model_id' do
        expect(resolved_id.model_id).to eq('secret_detection')
      end

      it 'has the correct model_name' do
        expect(resolved_id.model_name).to eq('Security::ScanProfile')
      end

      it 'matches the output of Gitlab::GlobalId.build' do
        expected_id = ::Gitlab::GlobalId.build(scan_profile, id: scan_profile.scan_type)
        expect(resolved_id.to_s).to eq(expected_id.to_s)
      end
    end
  end
end
