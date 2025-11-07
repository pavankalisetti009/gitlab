# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::GitlabSearchService, feature_category: :mcp_server do
  let(:mock_tool_global) { instance_double(Mcp::Tools::ApiTool, name: :gitlab_search_in_instance) }
  let(:mock_tool_group) { instance_double(Mcp::Tools::ApiTool, name: :gitlab_search_in_group) }
  let(:mock_tool_project) { instance_double(Mcp::Tools::ApiTool, name: :gitlab_search_in_project) }
  let(:tools) { [mock_tool_global, mock_tool_group, mock_tool_project] }
  let(:service) { described_class.new(tools: tools) }

  describe '#description' do
    it 'returns the correct description' do
      expect(service.description).to eq("" \
        "Search across GitLab with automatic selection of the best available search method.\n\n" \
        "**Capabilities:** basic (keywords, file filters)\n\n" \
        "**Syntax Examples:**\n- Basic: \"bug fix\", \"filename:*.rb\", \"extension:js\"")
    end

    context 'when advanced search is enabled' do
      it 'returns the correct description' do
        stub_ee_application_setting(elasticsearch_search: true)

        expect(service.description).to include('advanced (boolean operators)')
      end
    end

    context 'when exact code search is enabled' do
      it 'returns the correct description' do
        allow(::Search::Zoekt).to receive(:enabled?).and_return(true)

        expect(service.description).to include('exact code (exact match, regex, symbols)')
      end
    end
  end
end
