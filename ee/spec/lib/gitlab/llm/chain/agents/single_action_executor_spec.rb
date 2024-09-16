# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::SingleActionExecutor, feature_category: :duo_chat do
  include FakeBlobHelpers

  describe "#execute" do
    subject(:answer) { agent.execute }

    let(:agent) do
      described_class.new(
        user_input: user_input,
        tools: tools,
        context: context,
        response_handler: response_service_double,
        stream_response_handler: stream_response_service_double
      )
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:user) { create(:user).tap { |u| project.add_developer(u) } }

    let(:resource) { issue }
    let(:user_input) { 'question?' }
    let(:tools) { [Gitlab::Llm::Chain::Tools::IssueReader] }
    let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueReader::Executor) }
    let(:response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:stream_response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:extra_resource) { {} }
    let(:current_file) { nil }

    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user, container: nil, resource: resource, ai_request: nil,
        extra_resource: extra_resource, current_file: current_file, agent_version: nil
      )
    end

    let(:issue_resource) { Ai::AiResource::Issue.new(user, resource) }
    let(:answer_chunk) { create(:final_answer_chunk, chunk: "Ans") }

    let(:step_params) do
      {
        prompt: user_input,
        options: {
          chat_history: [],
          context: {
            type: issue_resource.current_page_type,
            content: issue_resource.current_page_short_description
          },
          current_file: nil,
          additional_context: []
        },
        model_metadata: nil,
        unavailable_resources: %w[Pipelines Vulnerabilities]
      }
    end

    let(:action_event) do
      Gitlab::Duo::Chat::AgentEvents::Action.new(
        {
          "thought" => 'I think I need to use issue_reader',
          "tool" => 'issue_reader',
          "tool_input" => '#123'
        }
      )
    end

    before do
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).and_return(
        Gitlab::Llm::Utils::Authorizer::Response.new(allowed: true)
      )
      allow(Gitlab::AiGateway).to receive(:headers).and_return({})
    end

    context "when answer is final" do
      let(:another_chunk) { create(:final_answer_chunk, chunk: "wer") }
      let(:first_response_double) { double }
      let(:second_response_double) { double }

      before do
        event_1 = Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta.new({ "text" => "Ans" })
        event_2 = Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta.new({ "text" => "wer" })

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event_1).and_yield(event_2).and_return([event_1, event_2])
        end

        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with(event_1.text, { chunk_id: 1 })
                                                                            .and_return(first_response_double)
        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with(event_2.text, { chunk_id: 2 })
                                                                            .and_return(second_response_double)
      end

      it "streams final answer" do
        expect(stream_response_service_double).to receive(:execute).with(
          response: first_response_double,
          options: { chunk_id: 1 }
        )
        expect(stream_response_service_double).to receive(:execute).with(
          response: second_response_double,
          options: { chunk_id: 2 }
        )

        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("Answer")
      end
    end

    context "when tool answer if final" do
      let(:tool_answer) { create(:answer, :final, content: 'tool answer') }

      before do
        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use issue_reader',
            "tool" => 'issue_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(tool_answer)
        end
      end

      it "returns tool answer" do
        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("tool answer")
      end
    end

    context "when tool is not found" do
      before do
        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use undef_reader',
            "tool" => 'undef_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end
      end

      it "returns an error answer" do
        expect(answer.is_final?).to be_truthy
        expect(answer.content).to eq("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to eq("A9999")
      end
    end

    context "when max iteration reached" do
      let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

      before do
        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)

        event = Gitlab::Duo::Chat::AgentEvents::Action.new(
          {
            "thought" => 'I think I need to use issue_reader',
            "tool" => 'issue_reader',
            "tool_input" => '#123'
          }
        )

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
            .and_yield(event).and_return([event])
        end

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(llm_answer)
        end
      end

      it "returns default answer" do
        expect(answer.is_final?).to eq(true)
        expect(answer.content).to include(Gitlab::Llm::Chain::Answer.default_final_message)
      end
    end

    context "when unknown event received" do
      before do
        event = Gitlab::Duo::Chat::AgentEvents::Unknown.new({ "text" => 'foo' })

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).with(step_params)
                                              .and_yield(event).and_return([event])
        end
      end

      it "returns unknown answer as is" do
        expect(answer.content).to include('foo')
      end
    end

    context "when resource is not authorized" do
      let!(:user) { create(:user) }

      it "sends request without context" do
        params = step_params
        params[:options][:context] = nil

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when code is selected" do
      let(:selected_text) { 'code selection' }
      let(:current_file) do
        {
          file_name: 'test.py',
          selected_text: selected_text,
          cotent_above_cursor: 'prefix',
          content_below_cursor: 'suffix'
        }
      end

      it "adds code file params to the question options" do
        params = step_params
        params[:options][:current_file] = {
          file_path: 'test.py',
          data: 'code selection',
          selected_code: true
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when code file is included in context" do
      let(:project) { build(:project) }
      let(:blob) { fake_blob(path: 'never.rb', data: 'puts "gonna give you up"') }
      let(:extra_resource) { { blob: blob } }

      it "adds code file params to the question options" do
        params = step_params
        params[:options][:current_file] = {
          file_path: 'never.rb',
          data: 'puts "gonna give you up"',
          selected_code: false
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context 'when Duo chat is self-hosted' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'test_token') }
      let_it_be(:ai_feature) { create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat) }

      it 'sends the self-hosted model metadata' do
        params = step_params
        params[:model_metadata] = {
          api_key: "test_token",
          endpoint: "http://localhost:11434/v1",
          name: "mistral",
          provider: :openai
        }

        expect_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          expect(react_agent).to receive(:step).with(params)
            .and_yield(action_event).and_return([action_event])
        end

        agent.execute
      end
    end

    context "when times out error is raised" do
      let(:error) { Net::ReadTimeout.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      shared_examples "time out error" do
        it "returns an error" do
          expect(answer.is_final?).to eq(true)
          expect(answer.content).to include("I'm sorry, I couldn't respond in time. Please try again.")
          expect(answer.error_code).to include("A1000")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end

      context "when streamed request times out" do
        before do
          allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
            allow(react_agent).to receive(:step).and_raise(error)
          end
        end

        it_behaves_like "time out error"
      end

      context "when tool times out out" do
        let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

        before do
          allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
            allow(react_agent).to receive(:step).with(step_params)
              .and_yield(action_event).and_return([action_event])
          end

          allow(::Gitlab::Llm::Chain::Answer).to receive(:from_response).and_return(llm_answer)
          allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
            allow(issue_tool).to receive(:execute).and_raise(error)
          end

          allow(stream_response_service_double).to receive(:execute)
        end

        it_behaves_like "time out error"
      end
    end

    context "when connection error is raised" do
      let(:error) { ::Gitlab::Llm::AiGateway::Client::ConnectionError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        allow_next_instance_of(Gitlab::Duo::Chat::StepExecutor) do |react_agent|
          allow(react_agent).to receive(:step).and_raise(error)
        end
      end

      it "returns an error" do
        expect(answer.is_final).to eq(true)
        expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to include("A1001")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end
  end
end
