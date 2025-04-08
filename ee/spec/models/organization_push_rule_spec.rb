# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OrganizationPushRule, type: :model, feature_category: :source_code_management do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'validations' do
    subject { build(:organization_push_rule) }

    it { is_expected.to be_valid }
  end
end
