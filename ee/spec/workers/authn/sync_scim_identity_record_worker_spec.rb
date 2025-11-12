# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncScimIdentityRecordWorker, feature_category: :system_access do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'is a no-op' do
      # Worker has been converted to no-op as part of worker removal process
      # The actual sync logic has been removed and will be fully deleted in a future release
      expect { worker.perform({}) }.not_to raise_error
    end
  end
end
