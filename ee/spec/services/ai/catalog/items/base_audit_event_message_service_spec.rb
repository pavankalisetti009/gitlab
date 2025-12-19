# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::BaseAuditEventMessageService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:version) { agent.latest_version }

  let(:params) { {} }
  let(:item_type) { 'test_item' }
  let(:item_type_label) { 'Test Item' }
  let(:event_type) { "create_ai_catalog_#{item_type}" }

  let(:service) do
    Class.new(described_class) do
      def item_type
        'test_item'
      end

      def item_type_label
        'Test Item'
      end

      def expected_schema_version
        1
      end

      def create_messages
        ["Created #{item_type_label}"]
      end

      def build_change_descriptions
        []
      end
    end.new(event_type, agent, params)
  end

  describe '#messages' do
    subject(:messages) { service.messages }

    context "when event_type is create_ai_catalog_item_type" do
      let(:event_type) { "create_ai_catalog_#{item_type}" }

      it "returns create messages for item_type" do
        expect(messages).to eq(["Created #{item_type_label}"])
      end
    end

    context "when event_type is delete_ai_catalog_item_type" do
      let(:event_type) { "delete_ai_catalog_#{item_type}" }

      it "returns delete message for item_type" do
        expect(messages).to eq(["Deleted #{item_type_label}"])
      end
    end

    context "when event_type is enable_ai_catalog_item_type" do
      let(:event_type) { "enable_ai_catalog_#{item_type}" }

      it "returns enable message with default scope for item_type" do
        expect(messages).to eq(["Enabled #{item_type_label} for project/group"])
      end

      context 'when scope is project' do
        let(:params) { { scope: 'project' } }

        it "returns enable message with project scope for item_type" do
          expect(messages).to eq(["Enabled #{item_type_label} for project"])
        end
      end

      context 'when scope is group' do
        let(:params) { { scope: 'group' } }

        it "returns enable message with group scope for item_type" do
          expect(messages).to eq(["Enabled #{item_type_label} for group"])
        end
      end
    end

    context "when event_type is disable_ai_catalog_item_type" do
      let(:event_type) { "disable_ai_catalog_#{item_type}" }

      it "returns disable message with default scope for item_type" do
        expect(messages).to eq(["Disabled #{item_type_label} for project/group"])
      end

      context 'when scope is project' do
        let(:params) { { scope: 'project' } }

        it "returns disable message with project scope for item_type" do
          expect(messages).to eq(["Disabled #{item_type_label} for project"])
        end
      end

      context 'when scope is group' do
        let(:params) { { scope: 'group' } }

        it "returns disable message with group scope for item_type" do
          expect(messages).to eq(["Disabled #{item_type_label} for group"])
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

  describe '#format_list' do
    let(:event_type) { "create_ai_catalog_#{item_type}" }

    it 'formats empty list as []' do
      result = service.send(:format_list, [])
      expect(result).to eq('[]')
    end

    it 'formats single item list' do
      result = service.send(:format_list, ['item1'])
      expect(result).to eq('[item1]')
    end

    it 'formats multiple items list with comma separation' do
      result = service.send(:format_list, %w[item1 item2 item3])
      expect(result).to eq('[item1, item2, item3]')
    end

    it 'formats nil as []' do
      result = service.send(:format_list, nil)
      expect(result).to eq('[]')
    end
  end

  describe 'abstract methods' do
    let(:event_type) { "create_ai_catalog_#{item_type}" }

    context 'when item_type is not implemented' do
      let(:service) do
        described_class.new(event_type, agent, params)
      end

      it 'raises NotImplementedError' do
        expect { service.send(:item_type) }.to raise_error(NotImplementedError)
        expect { service.send(:item_type_label) }.to raise_error(NotImplementedError)
        expect { service.send(:expected_schema_version) }.to raise_error(NotImplementedError)
        expect { service.send(:create_messages) }.to raise_error(NotImplementedError)
        expect { service.send(:build_change_descriptions) }.to raise_error(NotImplementedError)
      end
    end
  end
end
