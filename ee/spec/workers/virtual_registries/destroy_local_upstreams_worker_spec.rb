# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::DestroyLocalUpstreamsWorker, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:deleted_project) { create(:project) }
  let_it_be(:deleted_project_global_id) { deleted_project.to_global_id.to_s }
  let_it_be(:deleted_group) { create(:group) }
  let_it_be(:deleted_group_global_id) { deleted_group.to_global_id.to_s }

  let_it_be(:project_deleted_event) do
    ::Projects::ProjectDeletedEvent.new(
      data: { project_id: deleted_project.id, namespace_id: deleted_project.namespace_id }
    )
  end

  let_it_be(:group_deleted_event) do
    ::Groups::GroupDeletedEvent.new(data: { group_id: deleted_group.id, root_namespace_id: deleted_group.id })
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it 'has the correct worker attributes' do
    expect(described_class.get_feature_category).to eq(:virtual_registry)
    expect(described_class.get_urgency).to eq(:low)
  end

  describe '#handle_event' do
    shared_examples 'not removing any maven upstream' do
      it 'does not remove any maven upstream' do
        expect { consume }.not_to change { ::VirtualRegistries::Packages::Maven::Upstream.count }
      end
    end

    subject(:consume) { consume_event(subscriber: described_class, event: event) }

    context 'with maven linked upstream' do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
      let_it_be_with_reload(:local_upstream) do
        create(:virtual_registries_packages_maven_upstream, :without_credentials)
      end

      let_it_be(:local_registry_upstream) do
        create(:virtual_registries_packages_maven_registry_upstream, upstream: local_upstream, registry: registry)
      end

      let_it_be(:second_registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }

      where(:event, :url) do
        ref(:project_deleted_event) | ref(:deleted_project_global_id)
        ref(:group_deleted_event)   | ref(:deleted_group_global_id)
      end

      with_them do
        before do
          local_upstream.update!(url:)
        end

        it 'removes the upstream and sync the registry positions' do
          expect { consume }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
            .and change { second_registry_upstream.reload.position }.from(2).to(1)
        end
      end
    end

    context 'with no linked upstream' do
      context 'for project event' do
        let(:event) { project_deleted_event }

        it_behaves_like 'not removing any maven upstream'
      end

      context 'for group event' do
        let(:event) { group_deleted_event }

        it_behaves_like 'not removing any maven upstream'
      end
    end

    context 'with wrong event class' do
      let(:event) { Ci::PipelineCreatedEvent.new(data: { pipeline_id: 5 }) }

      it_behaves_like 'not removing any maven upstream'
    end

    context 'with id field not set' do
      before do
        allow_next_instance_of(described_class) do |worker|
          orig_method = worker.method(:handle_event)
          allow(worker).to receive(:handle_event) do |event|
            allow(event).to receive(:data).and_return({})

            orig_method.call(event)
          end
        end
      end

      context 'for project event' do
        let(:event) { project_deleted_event }

        it_behaves_like 'not removing any maven upstream'
      end

      context 'for group event' do
        let(:event) { group_deleted_event }

        it_behaves_like 'not removing any maven upstream'
      end
    end

    context 'with no global_id resolved' do
      before do
        allow_next_instance_of(target_class) do |target_instance|
          allow(target_instance).to receive(:to_global_id).and_return(nil)
        end
      end

      context 'for project event' do
        let(:event) { project_deleted_event }
        let(:target_class) { ::Project }

        it_behaves_like 'not removing any maven upstream'
      end

      context 'for group event' do
        let(:event) { group_deleted_event }
        let(:target_class) { ::Group }

        it_behaves_like 'not removing any maven upstream'
      end
    end
  end
end
