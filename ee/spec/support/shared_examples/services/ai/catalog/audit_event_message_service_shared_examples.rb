# frozen_string_literal: true

RSpec.shared_examples 'Ai::Catalog::AuditEventMessageService' do
  # Variables to be defined by consuming specs (in the it_behaves_like block):
  # - item_name: 'agent', 'flow', 'external agent'
  # - event_name_prefix: 'ai_catalog_agent', 'ai_catalog_flow', etc.
  # - schema_version_constant: Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION, etc.
  # - project: create(:project)
  # - item: create(item_factory, project: project)
  # - version: item.latest_version
  # - params: {}
  # - service: described_class.new(event_type, item, params)

  describe '#messages' do
    subject(:messages) { service.messages }

    context 'when schema version is other than what is expected in the service' do
      let(:event_type) { "create_#{event_name_prefix}" }

      before do
        allow(version).to receive(:schema_version).and_return(schema_version_constant + 1)
      end

      it 'raises an error with schema version mismatch message' do
        expect { messages }.to raise_error(
          RuntimeError,
          /Schema version mismatch for AI #{item_name}:/
        )
      end

      it 'includes service class name in error message' do
        expect { messages }.to raise_error(
          RuntimeError,
          /Please update/
        )
      end
    end

    context 'when event_type is delete' do
      let(:event_type) { "delete_#{event_name_prefix}" }

      it 'returns delete message' do
        expect(messages).to eq(["Deleted AI #{item_name}"])
      end
    end

    context 'when event_type is enable' do
      let(:event_type) { "enable_#{event_name_prefix}" }

      it 'returns enable message with default scope' do
        expect(messages).to eq(["Enabled AI #{item_name} for project/group"])
      end

      context 'when scope is project' do
        let(:params) { { scope: 'project' } }

        it 'returns enable message with project scope' do
          expect(messages).to eq(["Enabled AI #{item_name} for project"])
        end
      end

      context 'when scope is group' do
        let(:params) { { scope: 'group' } }

        it 'returns enable message with group scope' do
          expect(messages).to eq(["Enabled AI #{item_name} for group"])
        end
      end
    end

    context 'when event_type is disable' do
      let(:event_type) { "disable_#{event_name_prefix}" }

      it 'returns disable message with default scope' do
        expect(messages).to eq(["Disabled AI #{item_name} for project/group"])
      end

      context 'when scope is project' do
        let(:params) { { scope: 'project' } }

        it 'returns disable message with project scope' do
          expect(messages).to eq(["Disabled AI #{item_name} for project"])
        end
      end

      context 'when scope is group' do
        let(:params) { { scope: 'group' } }

        it 'returns disable message with group scope' do
          expect(messages).to eq(["Disabled AI #{item_name} for group"])
        end
      end
    end

    context 'when event_type is unknown' do
      let(:event_type) { 'unknown_event' }

      it 'returns empty array' do
        expect(messages).to eq([])
      end
    end
  end
end
