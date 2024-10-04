# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFieldSelectOption, feature_category: :team_planning do
  subject(:custom_field_select_option) { build(:custom_field_select_option) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:custom_field) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:value).scoped_to(:custom_field_id).case_insensitive }
  end
end
