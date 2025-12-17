# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersionPolicy, :with_current_organization, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  subject(:policy) { described_class.new(current_user, item_version) }

  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:reporter) { create(:user) }

  let(:current_user) { maintainer }

  let_it_be(:project) do
    create(:project, reporters: reporter, developers: developer, maintainers: maintainer)
  end

  let_it_be_with_reload(:item) { create(:ai_catalog_item, project: project, public: false) }
  let_it_be_with_reload(:published_item_version) { create(:ai_catalog_item_version, :released, item:, project:) }
  let_it_be_with_reload(:draft_item_version) { create(:ai_catalog_item_version, :draft, item:, project:) }

  let(:item_version) { published_item_version }

  let(:stage_check) { true }

  before do
    Current.organization = current_organization
    allow(::Gitlab::Llm::StageCheck).to receive(:available?)
      .with(project, :ai_catalog).and_return(stage_check)
  end

  describe 'execute_ai_catalog_item_version permission' do
    it { is_expected.to be_allowed(:execute_ai_catalog_item_version) }

    where(:current_user, :item_version, :allowed) do
      ref(:maintainer)  |  ref(:published_item_version)   | true
      ref(:developer)   |  ref(:published_item_version)   | true
      ref(:reporter)    |  ref(:published_item_version)   | false
      ref(:maintainer)  |  ref(:draft_item_version)       | true
      ref(:developer)   |  ref(:draft_item_version)       | false
      ref(:reporter)    |  ref(:draft_item_version)       | false
    end

    with_them do
      it "returns the correct permission" do
        expect(policy.allowed?(:execute_ai_catalog_item_version)).to eq(allowed)
      end
    end

    context 'when global_ai_catalog is not enabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it { is_expected.to be_disallowed(:execute_ai_catalog_item_version) }
    end

    context 'when ai catalog is not enabled for the project' do
      let(:stage_check) { false }

      it { is_expected.to be_disallowed(:execute_ai_catalog_item_version) }
    end
  end
end
