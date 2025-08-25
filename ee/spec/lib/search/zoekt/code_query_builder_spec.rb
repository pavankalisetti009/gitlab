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

    allow(auth).to receive(:get_access_levels_for_feature).with('repository')
        .and_return({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })
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
      let_it_be(:group) { create(:group) }

      let(:options) do
        {
          features: 'repository',
          current_user: current_user,
          group_id: group.id,
          search_level: :group
        }
      end

      before do
        guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 56, 99])
        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(search_level: :group, group_ids: [group.id]))
          .and_return(guest_projects)

        allow(auth).to receive(:get_traversal_ids_for_group)
          .with(group.id)
          .and_return("9970-")

        no_groups = class_double(ApplicationRecord, exists?: false)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::GUEST,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group))
          .and_return(no_groups)

        reporter_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::REPORTER,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group))
          .and_return(reporter_groups)

        allow(auth).to receive(:get_traversal_ids_for_groups)
          .with(reporter_groups,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group)
          .and_return(%w[9970-457- 9970-123-])
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

      let(:options) do
        {
          features: 'repository',
          current_user: current_user,
          search_level: :global
        }
      end

      before do
        guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1])
        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(min_access_level: ::Gitlab::Access::GUEST, group_ids: [],
            project_ids: [], search_level: :global))
          .and_return(guest_projects)

        reporter_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [56, 99])
        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER, group_ids: [],
            project_ids: [], search_level: :global))
          .and_return(reporter_projects)

        guest_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::GUEST,
            group_ids: [],
            project_ids: [],
            search_level: :global))
          .and_return(guest_groups)

        reporter_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::REPORTER,
            group_ids: [],
            project_ids: [],
            search_level: :global))
          .and_return(reporter_groups)

        allow(auth).to receive(:get_traversal_ids_for_groups)
          .with(guest_groups,
            group_ids: [],
            project_ids: [],
            search_level: :global)
          .and_return(%w[2270-])

        allow(auth).to receive(:get_traversal_ids_for_groups)
          .with(reporter_groups,
            group_ids: [],
            project_ids: [],
            search_level: :global)
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
