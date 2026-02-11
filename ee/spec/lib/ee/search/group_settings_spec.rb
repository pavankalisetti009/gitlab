# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Search results for settings", :js, feature_category: :global_search, type: :feature do
  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
    allow(Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(true)
    allow(Gitlab::Saas).to receive(:feature_available?).and_call_original
    allow(Gitlab::Saas).to receive(:feature_available?).with(:repositories_web_based_commit_signing).and_return(true)

    stub_licensed_features(
      group_level_merge_checks_setting: true,
      group_project_templates: true,
      custom_file_templates_for_namespace: true,
      pages_size_limit: true,
      protected_environments: true,
      push_rules: true,
      packages_virtual_registry: true
    )

    stub_config(dependency_proxy: { enabled: true })
    stub_feature_flags(configure_web_based_commit_signing: true)
  end

  it_behaves_like 'all group settings sections exist and have correct anchor links'
end
