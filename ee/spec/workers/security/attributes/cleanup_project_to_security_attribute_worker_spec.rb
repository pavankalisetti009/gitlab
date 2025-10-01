# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CleanupProjectToSecurityAttributeWorker, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }

  let_it_be(:security_category) { create(:security_category, namespace: namespace) }

  let_it_be(:attribute1) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr1")
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr2")
  end

  let_it_be(:attribute3) do
    create(:security_attribute, security_category: security_category, namespace: namespace, name: "attr3")
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    context 'with single attribute' do
      let(:attribute_ids) { attribute1.id }

      let!(:associations) do
        Array.new(5) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:other_associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations for the given attribute' do
        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-5)
      end

      it 'does not delete associations for other attributes' do
        worker.perform(attribute_ids)

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute2).count).to eq(3)
      end

      it 'returns success result' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(5)
      end
    end

    context 'with multiple attributes' do
      let(:attribute_ids) { [attribute1.id, attribute2.id] }

      let!(:associations1) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:associations2) do
        Array.new(4) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute2,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      let!(:associations3) do
        Array.new(2) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute3,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes associations for all given attributes' do
        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-7)
      end

      it 'does not delete associations for attributes not in the list' do
        worker.perform(attribute_ids)

        expect(Security::ProjectToSecurityAttribute.where(security_attribute: attribute3).count).to eq(2)
      end

      it 'returns success result with total deletion count' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(7)
      end
    end

    context 'with nil attribute_ids' do
      it 'returns early without performing any deletions' do
        expect(Security::Attributes::ProjectToSecurityAttributeDestroyService).not_to receive(:new)

        result = worker.perform(nil)

        expect(result).to be_nil
      end
    end

    context 'with empty attribute_ids array' do
      let(:attribute_ids) { [] }

      let!(:associations) do
        Array.new(3) do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'does not delete any associations' do
        expect { worker.perform(attribute_ids) }
          .not_to change { Security::ProjectToSecurityAttribute.count }
      end

      it 'returns success result with zero count' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(0)
      end
    end

    context 'when service returns error' do
      let(:attribute_ids) { attribute1.id }
      let(:error_message) { 'Database connection failed' }

      before do
        allow(Security::Attributes::ProjectToSecurityAttributeDestroyService)
          .to receive(:new).and_return(instance_double(
            Security::Attributes::ProjectToSecurityAttributeDestroyService,
            execute: ServiceResponse.error(message: error_message)
          ))
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(StandardError),
          hash_including(
            attribute_ids: attribute_ids,
            worker: 'Security::Attributes::CleanupProjectToSecurityAttributeWorker'
          )
        )

        worker.perform(attribute_ids)
      end

      it 'returns the error result' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be false
        expect(result.message).to eq(error_message)
      end
    end

    context 'when batch processing is needed' do
      let(:attribute_ids) { attribute1.id }

      before do
        stub_const('Security::Attributes::ProjectToSecurityAttributeDestroyService::BATCH_SIZE', 1)

        # Create more than batch size to test batching
        5.times do
          project = create(:project, namespace: namespace)
          create(:project_to_security_attribute, security_attribute: attribute1,
            project: project, traversal_ids: namespace.traversal_ids)
        end
      end

      it 'deletes all associations in batches' do
        expect { worker.perform(attribute_ids) }
          .to change { Security::ProjectToSecurityAttribute.count }.by(-5)
      end

      it 'returns success result with correct count' do
        result = worker.perform(attribute_ids)

        expect(result.success?).to be true
        expect(result.payload[:deleted_count]).to eq(5)
      end
    end
  end
end
