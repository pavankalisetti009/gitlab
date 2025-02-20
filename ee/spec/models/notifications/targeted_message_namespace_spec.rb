# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessageNamespace, feature_category: :acquisition do
  describe 'associations' do
    it { is_expected.to belong_to(:targeted_message).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    subject { build(:targeted_message_namespace) }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:targeted_message_id) }
  end
end
