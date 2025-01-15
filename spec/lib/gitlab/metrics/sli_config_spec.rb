# frozen_string_literal: true

require 'spec_helper'

module SliConfigTest
  class PumaSli
    include Gitlab::Metrics::SliConfig

    puma_enabled!
  end

  class SidekiqEeSli
    include Gitlab::Metrics::SliConfig

    sidekiq_enabled!
  end
end

RSpec.describe Gitlab::Metrics::SliConfig, feature_category: :error_budgets do
  describe '.sli_implementations' do
    specify do
      expect(described_class.sli_implementations).to include(SliConfigTest::PumaSli, SliConfigTest::SidekiqEeSli)
    end
  end
end
