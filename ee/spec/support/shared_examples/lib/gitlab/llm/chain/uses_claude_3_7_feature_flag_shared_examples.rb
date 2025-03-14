# frozen_string_literal: true

RSpec.shared_examples 'uses code_creation_slash_commands_claude_3_7 FF correctly' do
  before do
    allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)

    allow(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).with(user, {
      service_name: unit_primitive.to_sym,
      tracking_context: { request_id: nil, action: unit_primitive }
    }).and_return(ai_request_double)
  end

  describe 'without # frozen_string_literal: true FF' do
    before do
      stub_feature_flags(code_creation_slash_commands_claude_3_7: false)
    end

    it 'receives the default prompt verison' do
      expect(ai_request_double).to receive(:request).with(
        hash_including(options: hash_including(prompt_version: '^1.0.0')), unit_primitive: unit_primitive
      )

      tool.execute
    end
  end

  describe 'with code_creation_slash_commands_claude_3_7 FF' do
    before do
      stub_feature_flags(code_creation_slash_commands_claude_3_7: true)
    end

    it 'receives the dev prompt verison' do
      expect(ai_request_double).to receive(:request).with(
        hash_including(options: hash_including(prompt_version: '0.0.1-dev')), unit_primitive: unit_primitive
      )

      tool.execute
    end
  end
end
