# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::CodeQueryBuilder, feature_category: :global_search do
  subject(:result) { described_class.build(query: query, options: options) }

  let(:query) { 'test' }
  let(:current_user) { create(:user) }
  let(:auth) { instance_double(::Search::AuthorizationContext) }
  let(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
  let(:expected_extracted_result) do
    json_result = File.read(Rails.root.join(fixtures_path, extracted_result_path))
    ::Gitlab::Json.parse(json_result).deep_symbolize_keys
  end

  before do
    allow(Search::AuthorizationContext).to receive(:new).and_return(auth)
  end

  describe '#build' do
    context 'when project search' do
      let(:extracted_result_path) { 'search_project_meta_project_id.json' }

      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: 1,
          search_level: :project
        }
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end

      context 'when zoekt_search_meta_project_ids is disabled' do
        let(:extracted_result_path) { 'search_project.json' }

        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)
        end

        it 'builds the correct object' do
          expect(result).to eq(expected_extracted_result)
        end
      end
    end

    context 'when group search' do
      let(:extracted_result_path) { 'search_group_meta_project_id.json' }
      let(:group) { create(:group) }

      let(:options) do
        {
          current_user: current_user,
          group_id: group.id,
          search_level: :group
        }
      end

      before do
        allow(auth).to receive(:get_project_ids_for_user)
          .with(hash_including(search_level: :group, group_ids: [group.id])).and_return([1, 56, 99])
        allow(auth).to receive(:get_traversal_ids_for_group).with(group.id).and_return('9970-')
        allow(auth).to receive(:get_traversal_ids_for_user)
          .with(hash_including(group_ids: [group.id])).and_return(%w[9970-457- 9970-123-])
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end

      context 'when zoekt_search_meta_project_ids is disabled' do
        let(:extracted_result_path) { 'search_group_user_access.json' }

        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)
        end

        it 'builds the correct object' do
          expect(result).to eq(expected_extracted_result)
        end
      end
    end

    context 'when global search' do
      let(:extracted_result_path) { 'search_global_meta_project_id.json' }
      let(:group) { create(:group) }

      let(:options) do
        {
          features: 'repository',
          current_user: current_user,
          search_level: :global
        }
      end

      before do
        allow(auth).to receive(:get_project_ids_for_user)
          .with(hash_including(features: 'repository', group_ids: [], project_ids: [], search_level: :global))
          .and_return([1, 56, 99])
        allow(auth).to receive(:get_traversal_ids_for_group).with(group.id).and_return('9970-')
        allow(auth).to receive(:get_traversal_ids_for_user)
          .with(hash_including(features: 'repository', group_ids: [], project_ids: [], search_level: :global))
          .and_return(%w[9970-457- 9970-123-])
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end

      context 'when zoekt_search_meta_project_ids is disabled' do
        let(:extracted_result_path) { 'search_global.json' }

        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)
        end

        it 'builds the correct object' do
          expect(result).to eq(expected_extracted_result)
        end
      end
    end

    context 'when search_level is not recognized' do
      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: 1,
          search_level: :unrecognized
        }
      end

      it 'raises the exception' do
        expect { result }.to raise_error(
          ArgumentError, "Unsupported search level for zoekt search: #{options[:search_level]}"
        )
      end
    end
  end
end
