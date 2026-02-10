# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssuesSearch, :elastic_helpers, feature_category: :global_search do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:issue_epic_type) { create(:issue, :epic) }
  let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level) }
  let_it_be(:non_group_work_item) { create(:work_item, project: project) }
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    issue_epic_type.project = nil # Need to set this to nil as :epic feature is not enforing it.
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
  end

  describe '#maintain_elasticsearch_update' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[non_group_work_item])
      non_group_work_item.maintain_elasticsearch_update
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue_epic_type])
      issue_epic_type.maintain_elasticsearch_update
    end

    it 'calls track! for work_item' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item])
      work_item.maintain_elasticsearch_update
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue])
      issue.maintain_elasticsearch_update
    end
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[non_group_work_item])
      non_group_work_item.maintain_elasticsearch_create
    end

    it 'calls track! for work_item' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item])
      work_item.maintain_elasticsearch_create
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue_epic_type])
      issue_epic_type.maintain_elasticsearch_create
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[issue])
      issue.maintain_elasticsearch_create
    end
  end
end
