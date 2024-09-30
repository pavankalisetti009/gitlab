# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypeCustomField, feature_category: :team_planning do
  subject(:work_item_type_custom_field) { build(:work_item_type_custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item_type) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item_type) }
    it { is_expected.to validate_presence_of(:custom_field) }
    it { is_expected.to validate_uniqueness_of(:custom_field).scoped_to(:namespace_id, :work_item_type_id) }
  end
end
