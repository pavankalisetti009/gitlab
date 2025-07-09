# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Item, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:project).optional }

    it { is_expected.to have_many(:versions) }
    it { is_expected.to have_many(:consumers) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1_024) }

    it { expect(build(:ai_catalog_item)).to be_valid }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:item_type).with_values(agent: 1, flow: 2) }
  end
end
