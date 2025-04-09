# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter issues by custom fields', :js, feature_category: :team_planning do
  include FilteredSearchHelpers
  include_context 'with group configured with custom fields'

  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user) { create(:user) }
  let_it_be(:issue) { create(:issue, project: project) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    sign_in(user)
  end

  shared_examples 'custom fields filter visibility' do
    let(:query) { nil }

    context 'when custom fields feature is enabled' do
      before do
        stub_licensed_features(custom_fields: true)
        stub_feature_flags(custom_fields_feature: true)
      end

      it 'shows custom field tokens in filtered search' do
        visit issues_page_path

        click_filtered_search_bar

        aggregate_failures do
          within_testid('filtered-search-input') do
            expect(page).to have_content(select_field.name)
            expect(page).to have_content(multi_select_field.name)
            expect(page).not_to have_content(text_field.name)
            expect(page).not_to have_content(number_field.name)
          end
        end
      end
    end

    context 'when custom fields feature is disabled by license' do
      let(:query) { { "custom-field[#{select_field.id}]": select_option_2.id } }

      before do
        stub_licensed_features(custom_fields: false)
        stub_feature_flags(custom_fields_feature: true)
      end

      it 'does not show custom field tokens in filtered search or suggestions' do
        visit issues_page_path

        click_filtered_search_bar

        aggregate_failures do
          within_testid('filtered-search-input') do
            expect(page).not_to have_content(select_field.name)
            # even if there is no name the search field might try to tokenize the id
            expect(page).not_to have_content(select_option_2.id)
            expect(page).not_to have_content(multi_select_field.name)
            expect(page).not_to have_content(text_field.name)
            expect(page).not_to have_content(number_field.name)
          end
        end
      end
    end

    context 'when custom fields feature flag is disabled' do
      let(:query) { { "custom-field[#{select_field.id}]": select_option_2.id } }

      before do
        stub_licensed_features(custom_fields: true)
        stub_feature_flags(custom_fields_feature: false)

        visit issues_page_path
      end

      it 'does not show custom field tokens in filtered search' do
        click_filtered_search_bar

        aggregate_failures do
          within_testid('filtered-search-input') do
            expect(page).not_to have_content(select_field.name)
            expect(page).not_to have_content(select_option_2.id)
            expect(page).not_to have_content(multi_select_field.name)
            expect(page).not_to have_content(text_field.name)
            expect(page).not_to have_content(number_field.name)
          end
        end
      end
    end
  end

  context 'on project issues page' do
    let(:issues_page_path) { project_issues_path(project, query) }

    it_behaves_like 'custom fields filter visibility'
  end

  context 'on group issues page' do
    let(:issues_page_path) { issues_group_path(group, query) }

    it_behaves_like 'custom fields filter visibility'
  end

  context 'on subgroup issues page' do
    let(:issues_page_path) { issues_group_path(subgroup, query) }

    it_behaves_like 'custom fields filter visibility'
  end
end
