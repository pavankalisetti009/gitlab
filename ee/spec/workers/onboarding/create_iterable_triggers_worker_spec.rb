# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::CreateIterableTriggersWorker, :saas, type: :worker, feature_category: :onboarding do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(nil, []) }

    it 'does not error out' do
      expect { perform }.not_to raise_error
    end
  end
end
