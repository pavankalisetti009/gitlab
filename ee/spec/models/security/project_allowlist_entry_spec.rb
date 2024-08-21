# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectAllowlistEntry, feature_category: :secret_detection, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:scanner) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to allow_value(true, false).for(:active) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:scanner).with_values([:secret_push_protection]) }
    it { is_expected.to define_enum_for(:type).with_values([:path, :pattern, :raw_value]) }
  end
end
