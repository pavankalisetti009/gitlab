# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UserMetrics, feature_category: :ai_abstraction_layer do
  it { is_expected.to belong_to(:user).required }

  it { is_expected.to validate_presence_of(:last_duo_activity_on) }

  describe '.write_buffer' do
    it 'returns instance of AiUserMetricsDatabaseWriteBuffer' do
      expect(described_class.write_buffer).to be_instance_of(Analytics::AiUserMetricsDatabaseWriteBuffer)
    end
  end

  describe '.refresh_last_activity_on', :freeze_time do
    let_it_be(:user) { build_stubbed(:user) }

    it 'adds current timestamp to model buffer' do
      expect(described_class.write_buffer).to receive(:add).with({ user_id: user.id,
last_duo_activity_on: Time.current })

      described_class.refresh_last_activity_on(user)
    end

    it 'respects custom timestamp if provided' do
      expect(described_class.write_buffer).to receive(:add).with({ user_id: user.id,
last_duo_activity_on: 1.minute.ago })

      described_class.refresh_last_activity_on(user, last_duo_activity_on: 1.minute.ago)
    end
  end
end
