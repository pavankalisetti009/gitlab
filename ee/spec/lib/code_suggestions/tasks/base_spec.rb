# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::Base, feature_category: :code_suggestions do
  let(:klass) do
    Class.new(described_class) do
      def feature_setting_name
        :code_generations
      end
    end
  end

  describe '#base_url' do
    it 'returns correct URL' do
      expect(klass.new.base_url).to eql('https://cloud.gitlab.com/ai')
    end

    context 'when the feature is customized' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored) }

      it 'takes the base url from feature settings' do
        url = "http://localhost:5000"
        expect(::Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(url)

        expect(klass.new.base_url).to eq(url)
      end
    end
  end

  describe '#endpoint' do
    it 'raies NotImplementedError' do
      expect { klass.new.endpoint }.to raise_error(NotImplementedError)
    end
  end
end
