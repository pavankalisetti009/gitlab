# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group elastic search', :js, :elastic, :sidekiq_inline, :disable_rate_limiter,
  feature_category: :global_search do
  include ListboxHelpers

  let(:user) { create(:user) }
  let(:wiki) { create(:project_wiki, project: project) }
  let(:group_wiki) { create(:group_wiki, group: group) }
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, :wiki_repo, namespace: group) }

  def choose_group(group)
    find_by_testid('group-filter').click
    wait_for_requests

    within_testid('group-filter') do
      select_listbox_item group.name
    end
  end

  [:work_item, :issue].each do |document_type|
    context "when we have document_type as #{document_type}" do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        create(document_type, project: project, title: 'chosen issue title')
        stub_feature_flags(search_issues_uses_work_items_index: (document_type == :work_item))
        project.repository.index_commits_and_blobs
        stub_licensed_features(epics: true, group_wikis: true)
        stub_feature_flags(search_epics_uses_work_items_index: (document_type == :work_item))
        if document_type == :work_item # rubocop:disable RSpec/AvoidConditionalStatements -- We need to create objects based on document type.
          create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'chosen epic title')
        else
          create(:epic, group: group, title: 'chosen epic title')
        end

        Sidekiq::Worker.skipping_transaction_check do
          [group_wiki, wiki].each do |w|
            w.create_page('test.md', '# term')
            w.index_wiki_blobs
          end
        end
        ensure_elasticsearch_index!
        project.add_maintainer(user)

        sign_in(user)
        visit(search_path)
        wait_for_requests
        choose_group(group)
      end

      it 'finds all the scopes', :allowed_to_be_slow do
        # issues
        submit_search('chosen')
        select_search_scope('Issues')
        expect(page).to have_content('chosen issue title')

        # epics
        submit_search('chosen')
        select_search_scope('Epics')
        expect(page).to have_content('chosen epic title')

        # blobs
        submit_search('def')
        select_search_scope('Code')
        expect(page).to have_selector('.file-content .code')
        expect(page).to have_button('Copy file path')

        # commits
        submit_search('add')
        select_search_scope('Commits')
        expect(page).to have_selector('.commit-list > .commit')

        # wikis
        submit_search('term')
        select_search_scope('Wiki')
        expect(page).to have_selector('.search-result-row .description', text: 'term').twice
        expect(page).to have_link('test').twice
      end
    end
  end
end

RSpec.describe 'Group elastic search redactions', feature_category: :global_search do
  [:work_item, :issue].each do |document_type|
    context "when we have document_type as #{document_type}" do
      before do
        stub_feature_flags(search_issues_uses_work_items_index: (document_type == :work_item))
      end

      it_behaves_like 'a redacted search results page', document_type: document_type do
        let(:search_path) { group_path(public_group) }
      end
    end
  end
end
