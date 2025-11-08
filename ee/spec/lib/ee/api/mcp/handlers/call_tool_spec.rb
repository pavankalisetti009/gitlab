# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Handlers::CallTool, feature_category: :mcp_server do
  let(:manager) { instance_double(Mcp::Tools::Manager) }
  let(:request) { instance_double(Rack::Request) }
  let_it_be(:current_user) { create(:user) }

  subject(:handler) { described_class.new(manager) }

  # before_all do
  #   unless API::Mcp::Handlers::CallTool <= EE::API::Mcp::Handlers::CallTool
  #     require Rails.root.join('ee/lib/ee/api/mcp/handlers/call_tool')
  #     API::Mcp::Handlers::CallTool.prepend(EE::API::Mcp::Handlers::CallTool)
  #   end
  # end

  describe '#invoke' do
    let(:tool_name) { 'test_tool' }
    let(:params) { { name: tool_name, arguments: { param: 'value' } } }
    let(:tool) { instance_double(Mcp::Tools::BaseService) }

    before do
      allow(request).to receive(:[]).with(:id).and_return('1')
    end

    context 'when tool is found and version matches' do
      before do
        allow(manager).to receive(:get_tool).with(name: tool_name).and_return(tool)
        allow(tool).to receive(:is_a?).with(Mcp::Tools::CustomService).and_return(false)
        allow(tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
        allow(handler).to receive(:track_internal_event)
      end

      it 'executes the tool successfully and tracks events' do
        result = handler.invoke(request, params, current_user)

        expect(manager).to have_received(:get_tool).with(name: tool_name)
        expect(tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            session_id: '1'
          )
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            has_tool_call_success: 'true'
          )
        )
      end
    end

    context 'when tool is a custom service' do
      let(:custom_tool) { instance_double(Mcp::Tools::CustomService) }

      before do
        allow(manager).to receive(:get_tool).with(name: tool_name).and_return(custom_tool)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::CustomService).and_return(true)
        allow(custom_tool).to receive(:set_cred)
        allow(custom_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
        allow(handler).to receive(:track_internal_event)
      end

      it 'sets credentials before executing and tracks events' do
        result = handler.invoke(request, params, current_user)

        expect(custom_tool).to have_received(:set_cred).with(current_user: current_user)
        expect(custom_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            session_id: '1'
          )
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            has_tool_call_success: 'true'
          )
        )
      end
    end

    context 'when tool is not found' do
      before do
        allow(manager).to receive(:get_tool).with(name: tool_name)
          .and_raise(Mcp::Tools::Manager::ToolNotFoundError.new(tool_name))
        allow(handler).to receive(:track_internal_event)
      end

      it 'raises ArgumentError and tracks start and finish events' do
        expect { handler.invoke(request, params, current_user) }
          .to raise_error(ArgumentError, "Tool '#{tool_name}' not found.")

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            session_id: '1'
          )
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          namespace: current_user.namespace,
          additional_properties: hash_including(
            tool_name: tool_name,
            has_tool_call_success: 'false'
          )
        )
      end
    end
  end
end
