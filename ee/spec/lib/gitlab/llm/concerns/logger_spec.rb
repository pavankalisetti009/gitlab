# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Concerns::Logger, feature_category: :ai_abstraction_layer do
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:user) { build(:user) }
  let(:logged_params) { { message: 'test', event_name: 'test', ai_component: 'test', additional_option: 'test' } }
  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Concerns::Logger

      def method_with_error(logged_params)
        log_error(**logged_params)
      end

      def method_with_info(logged_params)
        log_info(**logged_params)
      end

      def method_with_conditional_info(user, logged_params)
        log_conditional_info(user, **logged_params)
      end
    end
  end

  subject(:instance) { dummy_class.new }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
  end

  describe '#log_conditional_info' do
    it 'calls logger with conditional_info method' do
      expect(logger).to receive(:conditional_info).with(user, klass: instance.class.to_s, **logged_params)

      instance.method_with_conditional_info(user, **logged_params)
    end
  end

  describe '#log_info' do
    it 'calls logger with info method' do
      expect(logger).to receive(:info).with(klass: instance.class.to_s, **logged_params)

      instance.method_with_info(**logged_params)
    end
  end

  describe '#log_error' do
    it 'calls logger with error method' do
      expect(logger).to receive(:error).with(klass: instance.class.to_s, **logged_params)

      instance.method_with_error(**logged_params)
    end
  end
end
