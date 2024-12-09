# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Setting, feature_category: :ai_abstraction_layer do
  describe 'associations' do
    it 'has expected associations' do
      is_expected.to belong_to(:amazon_q_oauth_application).class_name('Doorkeeper::Application').optional
      is_expected.to belong_to(:amazon_q_service_account_user).class_name('User').optional
    end
  end

  describe 'validations' do
    subject(:setting) { described_class.instance }

    context 'when validating ai_gateway_url length' do
      it { is_expected.to validate_length_of(:ai_gateway_url).is_at_most(2048).allow_nil }

      it 'is valid with a proper URL' do
        setting.ai_gateway_url = 'https://example.com/api'
        expect(setting).to be_valid
      end

      it 'is invalid with a blocked URL' do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError.new("URL is blocked"))

        setting.ai_gateway_url = 'https://blocked-url.com'
        expect(setting).not_to be_valid
        expect(setting.errors[:ai_gateway_url]).to include("is not allowed: URL is blocked")
      end

      it 'is invalid with a malformed URL' do
        setting.ai_gateway_url = 'not-a-url'
        expect(setting).not_to be_valid
        expect(setting.errors[:ai_gateway_url]).to include("is not allowed: Only allowed schemes are http, https")
      end
    end

    context 'when validating that the record is a singleton' do
      it 'allows creating the first record' do
        setting = described_class.new

        expect(setting).to be_valid
      end

      it 'prevents creating a second record' do
        _first_setting = described_class.create!
        second_setting = described_class.new

        expect(second_setting).not_to be_valid
        expect(second_setting.errors[:base]).to include('There can only be one Settings record')
      end

      it 'allows updating the existing record' do
        setting = described_class.create!

        setting.ai_gateway_url = 'https://new-url.example.com'

        expect(setting).to be_valid
      end

      it 'ensures only one record exists through the instance method' do
        first_instance = described_class.instance
        second_instance = described_class.instance

        expect(described_class.count).to eq(1)
        expect(first_instance).to eq(second_instance)
      end

      it "handles concurrent requests without uniqueness violations" do
        setting.destroy!
        barrier = Concurrent::CyclicBarrier.new(2)

        allow(described_class).to receive(:first) do
          # Simulate slow database query to force race condition
          sleep 0.1
          nil
        end

        thread1 = Thread.new do
          ApplicationRecord.connection_pool.with_connection do
            barrier.wait
            described_class.instance
          end
        end

        thread2 = Thread.new do
          ApplicationRecord.connection_pool.with_connection do
            barrier.wait
            described_class.instance
          end
        end

        expect do
          thread1.join
          thread2.join
        end.not_to raise_error

        expect(described_class.count).to eq(1)
      end
    end

    it { is_expected.to validate_length_of(:amazon_q_role_arn).is_at_most(2048).allow_nil }
  end
end
