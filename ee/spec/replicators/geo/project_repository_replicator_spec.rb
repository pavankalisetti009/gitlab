# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryReplicator, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:model_record) { create(:project_with_repo) }

  subject(:replicator) { model_record.replicator }

  context 'with project repository replication (V1)' do
    before do
      stub_feature_flags(geo_project_repository_replication_v2: false)
    end

    it_behaves_like 'a repository replicator'

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
    let(:primary_node) { create(:geo_node, :primary) }
    let(:secondary_node) { create(:geo_node) }

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
          before do
            stub_feature_flags(geo_project_repository_replication_v2: true)
          end

          it 'returns true for Project models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end
      end
    end
  end
end
