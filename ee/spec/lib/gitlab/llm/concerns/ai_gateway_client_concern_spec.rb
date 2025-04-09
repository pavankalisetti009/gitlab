# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Concerns::AiGatewayClientConcern, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { build(:user) }
  let_it_be(:tracking_context) { { source: 'test' } }
  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Concerns::AiGatewayClientConcern

      def initialize(user, tracking_context)
        @user = user
        @tracking_context = tracking_context
      end

      def inputs
        { input: 'test' }
      end

      def execute
        perform_ai_gateway_request!(user: @user, tracking_context: @tracking_context)
      end

      private

      def service_name
        'test'
      end

      def prompt_name
        'test'
      end
    end
  end

  subject(:fire_ai_gateway_request!) { dummy_class.new(user, tracking_context).execute }

  describe '#execute' do
    it 'executes the ai gateway request' do
      expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |instance|
        expect(instance).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: 'test',
          inputs: { input: 'test' },
          prompt_version: '^1.0.0',
          model_metadata: nil
        )
      end

      fire_ai_gateway_request!
    end

    context 'when the prompt version is overridden' do
      before do
        dummy_class.class_eval do
          def prompt_version
            '1.2.3'
          end
        end
      end

      it 'uses the overridden prompt version' do
        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |instance|
          expect(instance).to receive(:complete_prompt).with(
            base_url: ::Gitlab::AiGateway.url,
            prompt_name: 'test',
            inputs: { input: 'test' },
            prompt_version: '1.2.3',
            model_metadata: nil
          )
        end

        fire_ai_gateway_request!
      end
    end

    context 'when methods to be overridden are not implemented' do
      [:service_name, :prompt_name, :inputs].each do |method|
        it "raises an error when #{method} is not implemented" do
          dummy_class.class_eval do
            remove_method method
          end

          expect { fire_ai_gateway_request! }.to raise_error(NotImplementedError)
        end
      end
    end
  end
end
