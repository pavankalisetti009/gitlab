# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Glql::WorkItemsFinder, feature_category: :markdown do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:resource_parent) { group }
  let(:current_user)     { create(:user) }

  let(:context)          { instance_double(GraphQL::Query::Context) }
  let(:request_params)   { { 'operationName' => 'GLQL' } }
  let(:url_query)        { 'useES=true' }
  let(:url)              { 'http://localhost' }
  let(:referer)          { "#{url}?#{url_query}" }

  let(:dummy_request) do
    instance_double(ActionDispatch::Request,
      params: request_params,
      referer: referer
    )
  end

  let(:params) do
    {
      label_name: ['test-label'],
      state: 'opened',
      confidential: false
    }
  end

  before do
    allow(context).to receive(:[]).with(:request).and_return(dummy_request)
    allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(true)
    allow(resource_parent).to receive(:use_elasticsearch?).and_return(true)
  end

  subject(:finder) { described_class.new(current_user, context, resource_parent, params) }

  describe '#use_elasticsearch_finder?' do
    context 'when falling back to legacy finder' do
      context 'when the request is not a GLQL request' do
        let(:request_params) { { 'operationName' => 'Not GLQL' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when url param is not enabled' do
        let(:url_query) { 'useES=false' }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled per group' do
        before do
          allow(resource_parent).to receive(:use_elasticsearch?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when not supported search param is used' do
        let(:params) { { not_suported: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end
    end

    context 'when using ES finder' do
      context 'when all the conditions are met' do
        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when url param is missing (since we do not want to force using this param)' do
        let(:url_query) { '' }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end
    end
  end

  describe '#parent_param=' do
    context 'when resource_parent is a Group' do
      it 'sets the group_id and leaves project_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:project_id]).to be_nil
        expect(finder.params[:group_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:resource_parent) { project }

      it 'sets the project_id and leaves group_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:group_id]).to be_nil
        expect(finder.params[:project_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is not allowed' do
      let_it_be(:resource_parent) { create(:merge_request) }

      it 'sets the project_id and leaves group_id nil' do
        expect { finder.parent_param }.to raise_error(RuntimeError, 'Unexpected parent: MergeRequest')
      end
    end
  end

  describe '#execute' do
    let_it_be(:work_item1) { create(:work_item, project: project) }
    let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }
    let(:search_params) do
      {
        confidential: false,
        label_name: ['test-label'],
        per_page: 100,
        search: '*',
        sort: 'created_desc',
        state: 'opened'
      }
    end

    let(:search_results_double) { instance_double(Gitlab::Elastic::SearchResults, objects: [work_item1, work_item2]) }
    let(:search_service_double) { instance_double(SearchService, search_results: search_results_double) }

    before do
      finder.parent_param = resource_parent

      allow(SearchService)
        .to receive(:new)
        .with(current_user, search_params)
        .and_return(search_service_double)
    end

    context 'when resource_parent is a Project' do
      let(:resource_parent) { project }

      before do
        search_params.merge!(project_id: project.id)
      end

      it 'executes ES search service with expected params' do
        expect(finder.execute).to contain_exactly(work_item1, work_item2)
      end
    end

    context 'when resource_parent is a Group' do
      before do
        search_params.merge!(group_id: group.id)
      end

      it 'executes ES search service with expected params' do
        expect(finder.execute).to contain_exactly(work_item1, work_item2)
      end
    end
  end
end
