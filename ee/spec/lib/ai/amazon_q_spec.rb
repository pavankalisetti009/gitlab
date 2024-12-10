# frozen_string_literal: true

require 'spec_helper'

using RSpec::Parameterized::TableSyntax

RSpec.describe Ai::AmazonQ, feature_category: :ai_abstraction_layer do
  let(:application_settings) { ::Gitlab::CurrentSettings.current_application_settings }

  describe '#connected?' do
    where(:q_available, :q_ready, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        Ai::Setting.instance.update!(amazon_q_ready: q_ready)
        allow(described_class).to receive(:feature_available?).and_return(q_available)
      end

      it 'returns the expected result' do
        expect(described_class.connected?).to be result
      end
    end
  end

  describe '#feature_available?' do
    where(:feature_flag_enabled, :amazon_q_license_available, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(amazon_q: amazon_q_license_available)
        stub_feature_flags(amazon_q_integration: feature_flag_enabled)
      end

      it 'returns the expected result' do
        expect(described_class.feature_available?).to eq(result)
      end
    end
  end
end
