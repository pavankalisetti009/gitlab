# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomField, feature_category: :team_planning do
  subject(:custom_field) { build(:custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:select_options) }
    it { is_expected.to have_many(:work_item_type_custom_fields) }
    it { is_expected.to have_many(:work_item_types) }

    it 'orders select_options by position' do
      custom_field.save!

      option_1 = create(:custom_field_select_option, custom_field: custom_field, position: 2)
      option_2 = create(:custom_field_select_option, custom_field: custom_field, position: 1)

      expect(custom_field.select_options).to eq([option_2, option_1])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id).case_insensitive }
  end
end
