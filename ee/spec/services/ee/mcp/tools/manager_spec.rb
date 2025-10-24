# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Manager, feature_category: :ai_agents do
  let(:api_double) { class_double(API::API) }

  before do
    # Stub the CE CUSTOM_TOOLS with only CE tools
    ce_custom_tools = {
      'get_mcp_server_version' => Mcp::Tools::GetServerVersionService
    }
    stub_const("#{described_class}::CUSTOM_TOOLS", ce_custom_tools)

    # Stub the EE_CUSTOM_TOOLS with EE tools
    ee_custom_tools = {
      'semantic_code_search' => Mcp::Tools::SearchCodebaseService
    }
    stub_const("EE::#{described_class}::EE_CUSTOM_TOOLS", ee_custom_tools)
  end

  describe '#initialize' do
    let(:routes) { [] }

    before do
      stub_const('API::API', api_double)
      allow(api_double).to receive(:routes).and_return(routes)
    end

    context 'with no API routes' do
      it 'initializes with only custom tools' do
        manager = described_class.new

        expect(manager.tools.keys).to contain_exactly('get_mcp_server_version', 'semantic_code_search')
      end
    end

    context 'with API routes that have MCP settings' do
      let(:app1) { instance_double(Grape::Endpoint) }
      let(:app2) { instance_double(Grape::Endpoint) }
      let(:route1) { instance_double(Grape::Router::Route, app: app1) }
      let(:route2) { instance_double(Grape::Router::Route, app: app2) }
      let(:routes) { [route1, route2] }
      let(:mcp_settings1) { { tool_name: :create_user, params: [:name, :email], version: '1.0.0' } }
      let(:mcp_settings2) { { tool_name: :delete_user, params: [:id], version: '1.1.0' } }
      let(:api_tool1) { instance_double(Mcp::Tools::ApiTool) }
      let(:api_tool2) { instance_double(Mcp::Tools::ApiTool) }

      before do
        allow(app1).to receive(:route_setting).with(:mcp).and_return(mcp_settings1)
        allow(app2).to receive(:route_setting).with(:mcp).and_return(mcp_settings2)
        allow(Mcp::Tools::ApiTool).to receive(:new).with(name: 'create_user', route: route1).and_return(api_tool1)
        allow(Mcp::Tools::ApiTool).to receive(:new).with(name: 'delete_user', route: route2).and_return(api_tool2)
      end

      it 'creates ApiTool instances for routes with MCP settings' do
        manager = described_class.new

        expect(manager.tools).to include(
          'create_user' => api_tool1,
          'delete_user' => api_tool2,
          'get_mcp_server_version' => be_a(Mcp::Tools::GetServerVersionService),
          'semantic_code_search' => be_a(Mcp::Tools::SearchCodebaseService)
        )
        expect(manager.tools.size).to eq(4)
      end

      it 'converts tool_name symbols to strings' do
        manager = described_class.new

        expect(manager.tools.keys).to include('create_user', 'delete_user')
        expect(manager.tools.keys).not_to include(:create_user, :delete_user)
      end
    end

    context 'with API routes that have blank MCP settings' do
      let(:app1) { instance_double(Grape::Endpoint) }
      let(:app2) { instance_double(Grape::Endpoint) }
      let(:app3) { instance_double(Grape::Endpoint) }
      let(:route1) { instance_double(Grape::Router::Route, app: app1) }
      let(:route2) { instance_double(Grape::Router::Route, app: app2) }
      let(:route3) { instance_double(Grape::Router::Route, app: app3) }
      let(:routes) { [route1, route2, route3] }
      let(:mcp_settings1) { { tool_name: :valid_tool, params: [:param] } }
      let(:api_tool1) { instance_double(Mcp::Tools::ApiTool) }

      before do
        allow(app1).to receive(:route_setting).with(:mcp).and_return(mcp_settings1)
        allow(app2).to receive(:route_setting).with(:mcp).and_return(nil)
        allow(app3).to receive(:route_setting).with(:mcp).and_return({})
        allow(Mcp::Tools::ApiTool).to receive(:new).with(name: 'valid_tool', route: route1).and_return(api_tool1)
      end

      it 'skips routes with blank MCP settings' do
        manager = described_class.new

        expect(manager.tools).to include(
          'valid_tool' => api_tool1,
          'get_mcp_server_version' => be_a(Mcp::Tools::GetServerVersionService),
          'semantic_code_search' => be_a(Mcp::Tools::SearchCodebaseService)
        )
        expect(manager.tools.size).to eq(3)
        expect(Mcp::Tools::ApiTool).to have_received(:new).once.with(name: 'valid_tool', route: route1)
        expect(Mcp::Tools::ApiTool).not_to have_received(:new).with('route2', route2)
        expect(Mcp::Tools::ApiTool).not_to have_received(:new).with('route3', route3)
      end
    end
  end

  describe '#list_tools' do
    it 'returns the tools hash' do
      manager = described_class.new

      expect(manager.list_tools).to eq(manager.tools)
    end
  end

  describe '#get_tool' do
    let(:manager) { described_class.new }

    context 'with custom tool' do
      context 'when requesting specific version' do
        it 'returns the correct version' do
          tool = manager.get_tool(name: 'get_mcp_server_version', version: '0.1.0')

          expect(tool).to be_a(Mcp::Tools::GetServerVersionService)
          expect(tool.version).to eq('0.1.0')
        end
      end

      context 'when requesting latest version' do
        it 'returns the latest version' do
          tool = manager.get_tool(name: 'get_mcp_server_version')

          expect(tool).to be_a(Mcp::Tools::GetServerVersionService)
          expect(tool.version).to eq('0.1.0')
        end
      end

      context 'when requesting non-existent version' do
        it 'raises VersionNotFoundError' do
          expect { manager.get_tool(name: 'get_mcp_server_version', version: '99.99.99') }
            .to raise_error(described_class::VersionNotFoundError) do |error|
              expect(error.tool_name).to eq('get_mcp_server_version')
              expect(error.requested_version).to eq('99.99.99')
              expect(error.available_versions).to eq(['0.1.0'])
            end
        end
      end
    end

    context 'with EE custom tool' do
      context 'when requesting specific version' do
        it 'returns the correct version' do
          tool = manager.get_tool(name: 'semantic_code_search', version: '0.1.0')

          expect(tool).to be_a(Mcp::Tools::SearchCodebaseService)
          expect(tool.version).to eq('0.1.0')
        end
      end

      context 'when requesting latest version' do
        it 'returns the latest version' do
          tool = manager.get_tool(name: 'semantic_code_search')

          expect(tool).to be_a(Mcp::Tools::SearchCodebaseService)
          expect(tool.version).to eq('0.1.0')
        end
      end

      context 'when requesting non-existent version' do
        it 'raises VersionNotFoundError' do
          expect { manager.get_tool(name: 'semantic_code_search', version: '99.99.99') }
            .to raise_error(::Mcp::Tools::Manager::VersionNotFoundError) do |error|
              expect(error.tool_name).to eq('semantic_code_search')
              expect(error.requested_version).to eq('99.99.99')
              expect(error.available_versions).to eq(['0.1.0'])
            end
        end
      end
    end

    context 'with non-existent tool' do
      it 'raises ToolNotFoundError' do
        expect { manager.get_tool(name: 'non_existent_tool') }
          .to raise_error(described_class::ToolNotFoundError) do |error|
            expect(error.tool_name).to eq('non_existent_tool')
          end
      end
    end

    context 'with invalid version format' do
      it 'raises InvalidVersionFormatError' do
        expect { manager.get_tool(name: 'get_mcp_server_version', version: 'invalid-version') }
          .to raise_error(described_class::InvalidVersionFormatError) do |error|
            expect(error.version).to eq('invalid-version')
          end
      end
    end
  end
end
