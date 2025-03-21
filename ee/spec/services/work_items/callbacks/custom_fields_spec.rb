# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::CustomFields, feature_category: :team_planning do
  include_context 'with group configured with custom fields'

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }

  let_it_be(:current_user) { create(:user, reporter_of: group) }

  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

  let(:params) do
    [
      { custom_field_id: text_field.id, text_value: 'some text' },
      { custom_field_id: number_field.id, number_value: 100 },
      { custom_field_id: select_field.id, selected_option_ids: [select_option_1.id] },
      { custom_field_id: multi_select_field.id, selected_option_ids: [
        multi_select_option_1.id, multi_select_option_2.id
      ] }
    ]
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  describe '#after_save' do
    subject(:after_save_callback) { callback.after_save }

    it 'sets the custom field values for the work item' do
      after_save_callback

      expect(custom_field_values_for(text_field).first.value).to eq('some text')
      expect(custom_field_values_for(number_field).first.value).to eq(100)
      expect(custom_field_values_for(select_field).first.custom_field_select_option_id).to eq(select_option_1.id)
      expect(custom_field_values_for(multi_select_field)).to contain_exactly(
        have_attributes(custom_field_select_option_id: multi_select_option_1.id),
        have_attributes(custom_field_select_option_id: multi_select_option_2.id)
      )
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'change_work_item_custom_field_value' }
      let(:category) { described_class.name }
      let(:namespace) { group }
      let(:user) { current_user }
    end

    context 'when there are existing values' do
      before do
        create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'existing text')
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 50)
      end

      let(:params) do
        [
          { custom_field_id: number_field.id, number_value: 100 }
        ]
      end

      it 'updates the given fields and leaves others as-is' do
        after_save_callback

        expect(custom_field_values_for(text_field).first.value).to eq('existing text')
        expect(custom_field_values_for(number_field).first.value).to eq(100)
      end
    end

    context 'when custom_fields_feature is disabled' do
      before do
        stub_feature_flags(custom_fields_feature: false)
      end

      it 'does not set any custom field values' do
        after_save_callback

        expect(custom_field_values_for(text_field)).to be_empty
        expect(custom_field_values_for(number_field)).to be_empty
        expect(custom_field_values_for(select_field)).to be_empty
        expect(custom_field_values_for(multi_select_field)).to be_empty
      end
    end

    context 'when user does not have access' do
      let(:current_user) { create(:user) }

      it 'does not set any custom field values' do
        after_save_callback

        expect(custom_field_values_for(text_field)).to be_empty
        expect(custom_field_values_for(number_field)).to be_empty
        expect(custom_field_values_for(select_field)).to be_empty
        expect(custom_field_values_for(multi_select_field)).to be_empty
      end
    end

    context 'when custom field ID is invalid' do
      let(:params) do
        [
          { custom_field_id: non_existing_record_id, text_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect { after_save_callback }.to raise_error(Issuable::Callbacks::Base::Error, /Invalid custom field ID/)
      end
    end

    context 'when there are validation errors' do
      let(:params) do
        [
          { custom_field_id: number_field.id, number_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect do
          after_save_callback
        end.to raise_error(Issuable::Callbacks::Base::Error, 'Validation failed: Value is not a number')
      end
    end

    context 'with unsupported custom field type' do
      let(:invalid_field) do
        create(:custom_field, namespace: group, work_item_types: [issue_type]).tap do |f|
          f.update_column(:field_type, -1)
        end
      end

      let(:params) do
        [
          { custom_field_id: invalid_field.id, text_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect do
          after_save_callback
        end.to raise_error(Issuable::Callbacks::Base::Error, /\AUnsupported field type/)
      end
    end
  end

  def custom_field_values_for(custom_field)
    value_class = if custom_field.field_type_text?
                    WorkItems::TextFieldValue
                  elsif custom_field.field_type_number?
                    WorkItems::NumberFieldValue
                  elsif custom_field.field_type_select?
                    WorkItems::SelectFieldValue
                  end

    value_class.where(work_item: work_item, custom_field: custom_field)
  end
end
