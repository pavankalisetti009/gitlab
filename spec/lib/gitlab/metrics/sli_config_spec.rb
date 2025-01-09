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
    ee_only!
  end
end

RSpec.describe Gitlab::Metrics::SliConfig, feature_category: :error_budgets do
  describe '.sli_implementations' do
    specify do
      expect(described_class.sli_implementations).to include(SliConfigTest::PumaSli, SliConfigTest::SidekiqEeSli)
    end
  end

  describe '.ee_only?' do
    specify { expect(SliConfigTest::PumaSli).not_to be_ee_only }

    specify { expect(SliConfigTest::SidekiqEeSli).to be_ee_only }
  end
end
