# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemPolicy, :with_current_organization, feature_category: :workflow_catalog do
  subject(:policy) { described_class.new(current_user, item) }

  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be_with_reload(:private_project) do
    create(:project, :private, guests: guest, reporters: reporter, developers: developer, maintainers: maintainer)
  end

  let_it_be(:other_organization) { create(:organization) }
  let_it_be_with_reload(:private_item) { create(:ai_catalog_item, project: private_project, public: false) }
  let_it_be_with_reload(:public_item) { create(:ai_catalog_item, project: private_project, public: true) }

  let_it_be_with_reload(:flow_item) do
    create(:ai_catalog_flow, project: private_project, public: true)
  end

  let_it_be_with_reload(:third_party_flow_item) do
    create(:ai_catalog_third_party_flow, project: private_project, public: true)
  end

  let(:stage_check) { true }
  let(:duo_features_enabled) { true }

  before do
    Current.organization = current_organization
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(private_project, :ai_catalog).and_return(stage_check)
    private_project.update!(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'no permissions' do
    it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
    it { is_expected.to be_disallowed(:read_ai_catalog_item) }
  end

  shared_examples 'read-only permissions' do
    it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
    it { is_expected.to be_allowed(:read_ai_catalog_item) }

    it_behaves_like 'no permissions with global_ai_catalog feature flag disabled'
    it_behaves_like 'no permissions with project stage check false, unless item is public'
    it_behaves_like 'no permissions when project Duo features disabled, unless item is public'
    it_behaves_like 'read-only permissions with deleted item'
  end

  shared_examples 'read-write permissions' do
    it { is_expected.to be_allowed(:admin_ai_catalog_item) }
    it { is_expected.to be_allowed(:read_ai_catalog_item) }

    it_behaves_like 'no permissions with global_ai_catalog feature flag disabled'
    it_behaves_like 'no permissions with project stage check false, unless item is public'
    it_behaves_like 'no permissions when project Duo features disabled, unless item is public'
    it_behaves_like 'read-only permissions with deleted item'
  end

  shared_examples 'no permissions with global_ai_catalog feature flag disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    include_examples 'no permissions'
  end

  shared_examples 'read-only permissions with deleted item' do
    before do
      item.deleted_at = 1.day.ago
    end

    it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
    it { is_expected.to be_allowed(:read_ai_catalog_item) }
  end

  shared_examples 'no permissions with project stage check false, unless item is public' do
    let(:stage_check) { false }

    it { is_expected.to be_disallowed(:admin_ai_catalog_item) }

    it 'is expected not to allow read_ai_catalog_item, unless item is public' do
      allowed = item.public?

      expect(policy.allowed?(:read_ai_catalog_item)).to eq(allowed)
    end
  end

  shared_examples 'no permissions when project Duo features disabled, unless item is public' do
    let(:duo_features_enabled) { false }

    it { is_expected.to be_disallowed(:admin_ai_catalog_item) }

    it 'is expected not to allow read_ai_catalog_item, unless item is public' do
      allowed = item.public?

      expect(policy.allowed?(:read_ai_catalog_item)).to eq(allowed)
    end
  end

  context 'when maintainer' do
    let(:current_user) { maintainer }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'read-write permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-write permissions'
    end
  end

  context 'when flow' do
    let(:current_user) { maintainer }
    let(:item) { flow_item }

    it_behaves_like 'read-write permissions'

    context 'with ai_catalog_flows is disabled' do
      before do
        stub_feature_flags(ai_catalog_flows: false)
      end

      it_behaves_like 'no permissions'
    end
  end

  context 'when not flow' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    it_behaves_like 'read-write permissions'

    context 'with ai_catalog_flows is disabled' do
      before do
        stub_feature_flags(ai_catalog_flows: false)
      end

      it_behaves_like 'read-write permissions'
    end
  end

  context 'when third_party_flow' do
    let(:current_user) { maintainer }
    let(:item) { third_party_flow_item }

    it_behaves_like 'read-write permissions'

    context 'with ai_catalog_third_party_flow is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it_behaves_like 'no permissions'
    end
  end

  context 'when not third_party_flow' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    it_behaves_like 'read-write permissions'

    context 'with ai_catalog_third_party_flows is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it_behaves_like 'read-write permissions'
    end
  end

  context 'when developer' do
    let(:current_user) { developer }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'read-only permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
    end
  end

  context 'when reporter' do
    let(:current_user) { reporter }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'no permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
    end
  end

  context 'when guest' do
    let(:current_user) { guest }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'no permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
    end
  end

  context 'when anonymous' do
    let(:current_user) { nil }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'no permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
    end
  end
end
