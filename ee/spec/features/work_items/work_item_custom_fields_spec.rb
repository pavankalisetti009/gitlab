# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Item Custom Fields', :js, feature_category: :team_planning do
  # Import custom fields setup
  include_context 'with group configured with custom fields'

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    # feature flag `custom_fields_feature` defaults `true`
    stub_licensed_features(custom_fields: true)
    sign_in(user)
  end

  context 'when custom fields feature is enabled and fields have values' do
    before_all do
      # Create field values
      create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'Sample text')
      create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 5)
      create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
        custom_field_select_option: select_option_1)
      create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_2)
      create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_3)
    end

    before do
      visit project_work_item_path(project, work_item)
    end

    it 'displays number type custom field value correctly' do
      within_testid('work-item-custom-field') do
        expect(page).to have_text('Sample text')
      end
    end

    it 'displays text type custom field value correctly' do
      within_testid('work-item-custom-field') do
        expect(page).to have_text('5')
      end
    end

    it 'displays single select custom field value correctly' do
      within_testid('work-item-custom-field') do
        expect(page).to have_text(select_option_1.value)
      end
    end

    it 'displays multi select custom field values correctly' do
      within_testid('work-item-custom-field') do
        expect(page).to have_text(multi_select_option_2.value)
        expect(page).to have_text(multi_select_option_3.value)
      end
    end

    it 'displays fields as read-only for users without update permissions' do
      project.add_guest(user)

      within_testid('work-item-custom-field') do
        all('input').each do |input|
          expect(input['disabled']).to eq('true')
        end
      end
    end
  end

  context 'when custom fields feature is disabled' do
    it 'does not display custom fields section' do
      stub_feature_flags(custom_fields_feature: false)
      visit project_work_item_path(project, work_item)

      expect(page).not_to have_selector('[data-testid="work-item-custom-field"]')
    end
  end
end
