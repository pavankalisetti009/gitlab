# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryReplicator, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:project) { create(:project_with_repo) }
  let(:model_record) { project }
  let(:primary_node) { create(:geo_node, :primary) }

  subject(:replicator) { model_record.replicator }

  context 'with project repository replication (V1)' do
    before do
      stub_feature_flags(geo_project_repository_replication_v2: false)
    end

    it_behaves_like 'a repository replicator'

    it 'invokes replicator.geo_handle_after_create on create' do
      # This is a hacky workaround used instead of the ActiveRecord based
      # method `expect_next_found_2_instances_of` because `replicator_class`
      # is not an ActiveRecord model.

      # We want to assert that Geo::ProjectRepositoryReplicator#geo_handle_after_create
      # is called twice - one for each of the two model's the replicator class supports
      expect_next_instance_of(described_class) do |replicator|
        expect(replicator).to receive(:geo_handle_after_create)
      end

      expect_next_instance_of(described_class) do |replicator|
        expect(replicator).to receive(:geo_handle_after_create)
      end

      model_record.save!
    end

    describe 'housekeeping implementation' do
      let_it_be(:pool_repository) { create(:pool_repository) }
      let_it_be(:model_record) { create(:project, pool_repository: pool_repository) }

      it 'calls Geo::CreateObjectPoolService' do
        stub_secondary_node

        expect_next_instance_of(Geo::CreateObjectPoolService) do |service|
          expect(service).to receive(:execute)
        end

        replicator.before_housekeeping
      end
    end
  end

  describe '.geo_project_repository_replication_v2_enabled?' do
    context 'when feature flag is enabled' do
      it 'returns true' do
        expect(described_class.geo_project_repository_replication_v2_enabled?).to be true
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(geo_project_repository_replication_v2: false)
      end

      it 'returns false' do
        expect(described_class.geo_project_repository_replication_v2_enabled?).to be false
      end
    end
  end

  describe '#should_publish_replication_event?' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'when parent method returns false' do
      before do
        allow(described_class).to receive(:replication_enabled?).and_return(false)
      end

      it 'returns false regardless of model type' do
        expect(replicator.should_publish_replication_event?).to be false
      end
    end

    context 'when parent method returns true' do
      before do
        allow(described_class).to receive(:replication_enabled?).and_return(true)
      end

      context 'with Project model' do
        context 'when v2 feature flag is disabled' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'returns true for Project models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end

        context 'when v2 feature flag is enabled' do
          it 'returns true for Project models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end
      end

      context 'with ProjectRepository model' do
        let(:model_record) { project.project_repository }

        context 'when v2 feature flag is disabled' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'returns false for ProjectRepository models' do
            expect(replicator.should_publish_replication_event?).to be false
          end
        end

        context 'when v2 feature flag is enabled' do
          it 'returns true for ProjectRepository models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end
      end
    end

    describe 'integration test for event publishing behavior' do
      let_it_be(:secondary) { create(:geo_node, :secondary) }

      before do
        # Calling these earlier, so that no unintended :created events are
        # not published during the tests
        replicator
        project.project_repository.replicator
      end

      context 'when v2 feature flag is disabled' do
        before do
          stub_feature_flags(geo_project_repository_replication_v2: false)
        end

        it 'publishes events for Project updates but not ProjectRepository updates' do
          expect { replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
          expect { project.project_repository.replicator.publish(:updated) }.not_to change { Geo::Event.count }
        end
      end

      context 'when v2 feature flag is enabled' do
        it 'publishes events for both Project and ProjectRepository updates' do
          expect { replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
          expect { project.project_repository.replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
        end
      end
    end
  end
end
