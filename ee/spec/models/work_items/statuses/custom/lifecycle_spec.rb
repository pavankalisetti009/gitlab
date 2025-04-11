# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Lifecycle, feature_category: :team_planning do
  subject(:custom_lifecycle) { build_stubbed(:work_item_custom_lifecycle) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:default_open_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_closed_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_duplicate_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:statuses).through(:lifecycle_statuses) }
    it { is_expected.to have_many(:type_custom_lifecycles) }
    it { is_expected.to have_many(:work_item_types).through(:type_custom_lifecycles) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    context 'with uniqueness validations' do
      subject(:custom_lifecycle) { create(:work_item_custom_lifecycle) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    end

    it { is_expected.to validate_presence_of(:default_open_status) }
    it { is_expected.to validate_presence_of(:default_closed_status) }
    it { is_expected.to validate_presence_of(:default_duplicate_status) }
  end
end
