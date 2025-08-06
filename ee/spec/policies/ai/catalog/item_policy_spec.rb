# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemPolicy, :with_current_organization, feature_category: :workflow_catalog do
  subject(:policy) { described_class.new(current_user, item) }

  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) do
    create(:project, guests: guest, reporters: reporter, developers: developer, maintainers: maintainer)
  end

  let_it_be(:other_organization) { create(:organization) }
  let_it_be_with_reload(:private_item) { create(:ai_catalog_item, project: project, public: false) }
  let_it_be_with_reload(:public_item) { create(:ai_catalog_item, project: project, public: true) }

  before do
    Current.organization = current_organization
  end

  shared_examples 'no permissions' do
    it { is_expected.not_to be_allowed(:admin_ai_catalog_item) }
    it { is_expected.not_to be_allowed(:read_ai_catalog_item) }
  end

  shared_examples 'read-only permissions' do
    it { is_expected.not_to be_allowed(:admin_ai_catalog_item) }
    it { is_expected.to be_allowed(:read_ai_catalog_item) }

    it_behaves_like 'no permissions with global_ai_catalog feature flag disabled'
    it_behaves_like 'no permissions with deleted item'
  end

  shared_examples 'read-write permissions' do
    it { is_expected.to be_allowed(:admin_ai_catalog_item) }
    it { is_expected.to be_allowed(:read_ai_catalog_item) }

    it_behaves_like 'no permissions with global_ai_catalog feature flag disabled'
    it_behaves_like 'no permissions with deleted item'
  end

  shared_examples 'no permissions with global_ai_catalog feature flag disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    include_examples 'no permissions'
  end

  shared_examples 'no permissions with deleted item' do
    before do
      item.deleted_at = 1.day.ago
    end

    include_examples 'no permissions'
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
end
