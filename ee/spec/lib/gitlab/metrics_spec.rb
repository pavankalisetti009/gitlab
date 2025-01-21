# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics, feature_category: :error_budgets do
  describe '.initialize_slis!', feature_category: :error_budgets do
    # This context is replicating the specs in spec/lib/gitlab/metrics_spec.rb
    # within the EE context.

    context 'when puma runtime' do
      it "initializes only puma SLIs" do
        allow(Gitlab::Runtime).to receive_messages(puma?: true, sidekiq?: false)
        # This will force rails to reload the classes and evaluate the defined SLIs again.
        # This time with runtime equal puma.
        Rails.application.eager_load!

        expect(Gitlab::Metrics::SliConfig.enabled_slis).to include(
          Gitlab::Metrics::RequestsRackMiddleware,
          Gitlab::Metrics::GlobalSearchSlis,
          Gitlab::Metrics::Middleware::PathTraversalCheck
        )
        expect(Gitlab::Metrics::SliConfig.enabled_slis).to all(receive(:initialize_slis!))

        described_class.initialize_slis!
      end
    end

    context 'when sidekiq runtime' do
      it "initializes only sidekiq SLIs" do
        allow(Gitlab::Runtime).to receive_messages(puma?: false, sidekiq?: true)
        # This will force rails to reload the classes and evaluate the defined SLIs again.
        # This time with runtime equal sidekiq.
        Rails.application.eager_load!

        expect(Gitlab::Metrics::SliConfig.enabled_slis).to include(
          Gitlab::Metrics::Lfs,
          Gitlab::Metrics::LooseForeignKeysSlis,
          Gitlab::Metrics::GlobalSearchIndexingSlis,
          Gitlab::Metrics::Llm,
          Gitlab::Metrics::SecurityScanSlis
        )
        expect(Gitlab::Metrics::SliConfig.enabled_slis).to all(receive(:initialize_slis!))

        described_class.initialize_slis!
      end
    end
  end
end
