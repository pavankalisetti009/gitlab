# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionEvent, feature_category: :code_suggestions do
  subject(:event) { described_class.new }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:organization_id) }
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(event.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#organization_id' do
    let(:user) { build_stubbed(:user, :with_namespace) }

    subject(:event) { described_class.new(user: user).tap(&:valid?) }

    it 'populates organization_id from user namespace' do
      expect(event.organization_id).to be_present
      expect(event.organization_id).to eq(user.namespace.organization_id)
    end
  end
end
