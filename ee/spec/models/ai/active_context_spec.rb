# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext, feature_category: :global_search do
  describe '.paused?' do
    subject(:paused) { described_class.paused? }

    context 'when indexing is disabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'when indexing is enabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
      end

      context 'when active_context connection is not using advanced search config' do
        before do
          allow(::ActiveContext).to receive_message_chain(
            :adapter, :connection, :use_advanced_search_config?
          ).and_return(false)
        end

        it { is_expected.to be false }
      end

      context 'when active_context connection is using advanced search config' do
        before do
          allow(::ActiveContext).to receive_message_chain(
            :adapter, :connection, :use_advanced_search_config?
          ).and_return(true)
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_pause_indexing?).and_return(true)
        end

        it 'uses the advanced search config value' do
          expect(paused).to be true
        end
      end
    end
  end
end
