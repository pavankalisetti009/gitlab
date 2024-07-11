# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# RepositoryReplicatorStrategy.
#
# Required let variables:
#
# - model_record: A valid, unpersisted instance of the model class. Or a valid,
#                 persisted instance of the model class in a not-yet loaded let
#                 variable (so we can trigger creation).
#
RSpec.shared_examples 'a repository replicator' do
  include EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }

  let(:housekeeping_model_record) { model_record }

  subject(:replicator) { model_record.replicator }

  before do
    stub_current_geo_node(primary)
  end

  it_behaves_like 'a replicator' do
    let_it_be(:event_name) { ::Geo::RepositoryReplicatorStrategy::EVENT_UPDATED }
  end

  it_behaves_like 'a verifiable replicator'

  # This could be included in each model's spec, but including it here is DRYer.
  include_examples 'a replicable model' do
    let(:replicator_class) { described_class }
  end

  describe '#geo_handle_after_update' do
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record

        expect do
          replicator.geo_handle_after_update
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name, "event_name" => ::Geo::RepositoryReplicatorStrategy::EVENT_UPDATED, "payload" => { "model_record_id" => replicator.model_record.id })
      end

      it 'calls #before_verifiable_update' do
        expect(replicator).to receive(:before_verifiable_update)

        replicator.geo_handle_after_update
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replicator.replication_enabled_feature_key => false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_update
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_update
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe '#geo_handle_after_create' do
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record.save!

        expect do
          replicator.geo_handle_after_create
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::RepositoryReplicatorStrategy::EVENT_CREATED,
          "payload" => {
            "model_record_id" => replicator.model_record.id
          }
        )
      end

      it 'does not call #before_verifiable_update' do
        expect(replicator).not_to receive(:before_verifiable_update)

        replicator.geo_handle_after_create
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replicator.replication_enabled_feature_key => false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_create
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_create
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe '#geo_handle_after_destroy' do
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record

        expect do
          replicator.geo_handle_after_destroy
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name, "event_name" => ::Geo::RepositoryReplicatorStrategy::EVENT_DELETED)
        expect(::Geo::Event.last.payload).to include({ "model_record_id" => replicator.model_record.id })
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags("geo_#{replicator.replicable_name}_replication": false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_destroy
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_destroy
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe 'updated event consumption' do
    before do
      model_record.save!
    end

    context 'in replicables_for_current_secondary list' do
      it 'runs Geo::FrameworkRepositorySyncService service' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)
        sync_service = double

        expect(sync_service).to receive(:execute)
        expect(::Geo::FrameworkRepositorySyncService)
          .to receive(:new).with(replicator)
                .and_return(sync_service)

        replicator.consume(::Geo::RepositoryReplicatorStrategy::EVENT_UPDATED)
      end
    end

    context 'not in replicables_for_current_secondary list' do
      it 'does not run Geo::FrameworkRepositorySyncService service' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

        expect(::Geo::FrameworkRepositorySyncService)
          .not_to receive(:new)

        replicator.consume(::Geo::RepositoryReplicatorStrategy::EVENT_UPDATED)
      end
    end

    context 'when a sync is currently running' do
      let(:registry) { replicator.registry }

      it 'moves registry state to pending' do
        registry.start!

        # sync no-op, as if the lease is already taken
        allow(replicator).to receive(:sync_repository)

        expect do
          replicator.consume(::Geo::RepositoryReplicatorStrategy::EVENT_UPDATED)
        end.to change { registry.reload.pending? }.from(false).to(true)
          .and change { registry.reload.last_synced_at }.to(nil)
      end
    end
  end

  describe 'deleted event consumption' do
    it 'runs Geo::RepositoryRegistryRemovalService service' do
      model_record.save!

      sync_service = double

      expect(sync_service).to receive(:execute)

      expect(Geo::RepositoryRegistryRemovalService)
        .to receive(:new).with(replicator, {})
              .and_return(sync_service)

      replicator.consume(::Geo::RepositoryReplicatorStrategy::EVENT_DELETED)
    end
  end

  describe '.git_access_class' do
    it 'is implemented' do
      expect(replicator.class.git_access_class).to be < Gitlab::GitAccess
    end
  end

  describe '.no_repo_message' do
    it 'is implemented' do
      expect(replicator.class.no_repo_message).to be_a(String)
    end
  end

  describe '.housekeeping_enabled?' do
    it 'is implemented' do
      expect(replicator.class.housekeeping_enabled?).to be_in([true, false])
    end
  end

  describe '#housekeeping_model_record' do
    it 'is implemented' do
      expect(replicator.housekeeping_model_record).to eq(housekeeping_model_record)
    end
  end

  describe '#before_verifiable_update' do
    using RSpec::Parameterized::TableSyntax

    where(:primary, :verification_enabled, :checksum, :expect_verification_pending) do
      true  | true  | 'abc123' | true
      true  | false | 'abc123' | false
      false | true  | 'abc123' | false
      false | false | 'abc123' | false
    end

    with_them do
      before do
        if primary
          stub_primary_node
        else
          stub_secondary_node
        end

        allow(described_class).to receive(:verification_enabled?).and_return(verification_enabled)

        model_record.verification_started!
      end

      it 'marks pending verification only if needed' do
        replicator.before_verifiable_update

        expect(model_record.verification_pending?).to eq(expect_verification_pending)
      end
    end
  end

  describe '#model' do
    let(:invoke_model) { replicator.class.model }

    it 'is implemented' do
      expect do
        invoke_model
      end.not_to raise_error
    end

    it 'is a Class' do
      expect(invoke_model).to be_a(Class)
    end
  end

  describe '#mutable?' do
    it 'is true' do
      expect(replicator.mutable?).to eq(true)
    end
  end
end
