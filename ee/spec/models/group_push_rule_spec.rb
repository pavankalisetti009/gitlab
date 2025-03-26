# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPushRule, type: :model, feature_category: :source_code_management do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
  end
end
