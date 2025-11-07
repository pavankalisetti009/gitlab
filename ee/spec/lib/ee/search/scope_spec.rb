# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Scope, feature_category: :global_search do
  describe '.global' do
    context 'when all global search EE settings, zoekt, and elasticsearch_search are enabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, global_search_code_enabled: true,
          global_search_commits_enabled: true, global_search_epics_enabled: true, global_search_wiki_enabled: true)
        allow(::Search::Zoekt).to receive(:enabled?).and_return(true)
      end

      it 'returns all global allowed scopes' do
        expected_scopes = described_class::ALWAYS_ALLOWED_SCOPES + described_class::GLOBAL_SCOPES +
          described_class::ADVANCED_GLOBAL_SCOPES + described_class::ZOEKT_GLOBAL_SCOPES

        expect(described_class.global).to match_array(expected_scopes.uniq)
      end
    end

    context 'when some global search EE settings are disabled' do
      before do
        stub_ee_application_setting(global_search_code_enabled: false, global_search_epics_enabled: false)
      end

      it 'does not return those scopes' do
        expect(described_class.global).not_to include(%w[blobs epics])
      end
    end

    context 'when all global search settings are disabled' do
      before do
        stub_ee_application_setting(global_search_code_enabled: false,
          global_search_commits_enabled: false,
          global_search_epics_enabled: false,
          global_search_wiki_enabled: false)

        stub_application_setting(global_search_snippet_titles_enabled: false,
          global_search_issues_enabled: false,
          global_search_merge_requests_enabled: false,
          global_search_users_enabled: false)
      end

      it 'returns only scopes which cannot be globally disabled' do
        expect(described_class.global).to match_array(described_class::ALWAYS_ALLOWED_SCOPES)
      end
    end

    context 'when elasticsearch is disabled and zoekt is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false)
        allow(::Search::Zoekt).to receive(:enabled?).and_return(false)
      end

      it 'returns only base global scopes' do
        expected_scopes = described_class::ALWAYS_ALLOWED_SCOPES + described_class::GLOBAL_SCOPES

        expect(described_class.global).to match_array(expected_scopes)
      end
    end

    context 'when elasticsearch is enabled and zoekt is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: true)
        allow(::Search::Zoekt).to receive(:enabled?).and_return(false)
      end

      it 'returns base scopes plus advanced scopes' do
        expected_scopes = described_class::ALWAYS_ALLOWED_SCOPES + described_class::GLOBAL_SCOPES +
          described_class::ADVANCED_GLOBAL_SCOPES

        expect(described_class.global).to match_array(expected_scopes)
      end
    end

    context 'when elasticsearch is disabled and zoekt is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false)
        allow(::Search::Zoekt).to receive(:enabled?).and_return(true)
      end

      it 'returns base scopes plus zoekt scopes' do
        expected_scopes = described_class::ALWAYS_ALLOWED_SCOPES + described_class::GLOBAL_SCOPES +
          described_class::ZOEKT_GLOBAL_SCOPES

        expect(described_class.global).to match_array(expected_scopes)
      end
    end
  end
end
