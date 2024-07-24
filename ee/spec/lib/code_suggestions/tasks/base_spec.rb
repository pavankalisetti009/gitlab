# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::Base, feature_category: :code_suggestions do
  subject(:task) { described_class.new }

  describe '.base_url' do
    it 'returns correct URL' do
      expect(described_class.base_url).to eql('https://cloud.gitlab.com/ai')
    end
  end

  describe '#endpoint' do
    it 'raies NotImplementedError' do
      expect { task.endpoint }.to raise_error(NotImplementedError)
    end
  end
end
