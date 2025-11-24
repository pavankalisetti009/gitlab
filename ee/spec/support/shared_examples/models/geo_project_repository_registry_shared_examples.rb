# frozen_string_literal: true

# Shared examples for Geo::ProjectRepositoryRegistry tests.
#
# This shared example tests the Geo::ProjectRepositoryRegistry model behavior,
# including repository sync status checks and registry creation.
#
# These examples are designed to work with both v1 (Project-based) and v2
# (ProjectRepository-based) Geo replication implementations.
#
# Required variables (must be defined in the including spec):
#
# - model_record_key: Symbol indicating the key for the model record
#   Examples: :project (for v1), :project_repository (for v2)
#
# - model_record: The actual model instance to test with
#   Examples: create(:project_with_repo), create(:project_repository)
#
# - model_record_id: The ID of the model record
#   Example: model_record.id
#
# - project: The project instance (may be the same as model_record for v1)
#   Example: model_record (for v1) or model_record.project (for v2)
#
# Required helper methods (must be defined in the including spec):
#
# - create_model_record: Creates a new model record for testing
#   Example: def create_model_record; create(:project_with_repo); end
#
# - create_model_record_with_pipeline_refs(count): Creates a model record with pipeline refs
#   Example: def create_model_record_with_pipeline_refs(count = 10) do
#              create(:project, :pipeline_refs, pipeline_count: count)
#            end
#
# - update_last_repository_updated_at(value): Updates the last_repository_updated_at timestamp
#   Example: def update_last_repository_updated_at(value); model_record.update!(last_repository_updated_at: value); end
#
# - registry_project_id(registry): Returns the project ID from a registry
#   Example: def registry_project_id(registry); registry.project_id; end
#
RSpec.shared_examples 'Geo::ProjectRepositoryRegistry' do
  include ::EE::GeoHelpers

  let(:registry) do
    if model_record_key == :project_repository
      build(:geo_project_repository_registry, project: model_record.project)
    else
      build(:geo_project_repository_registry, model_record_key => model_record)
    end
  end

  def create_model_record
    create(:project_with_repo)
  end

  def create_model_record_with_pipeline_refs(pipeline_count = 10)
    create(:project, :pipeline_refs, pipeline_count: pipeline_count)
  end

  def update_last_repository_updated_at(value)
    model_record.update!(last_repository_updated_at: value)
  end

  def registry_project_id(registry)
    registry.project_id
  end

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'

  describe '.repository_out_of_date?' do
    let(:model_record) { create_model_record }

    context 'for a non-Geo setup' do
      it 'returns false' do
        expect(described_class.repository_out_of_date?(model_record_id)).to be_falsey
      end
    end

    context 'for a Geo setup' do
      before do
        stub_current_geo_node(current_node)
      end

      context 'for a Geo Primary' do
        let(:current_node) { create(:geo_node, :primary) }

        it 'returns false' do
          expect(described_class.repository_out_of_date?(model_record_id)).to be_falsey
        end
      end

      context 'for a Geo secondary' do
        let(:current_node) { create(:geo_node) }

        context 'when Primary node is not configured' do
          it 'returns false' do
            expect(described_class.repository_out_of_date?(model_record_id)).to be_falsey
          end
        end

        context 'when Primary node is configured' do
          before do
            create(:geo_node, :primary)
          end

          context 'when project_repository_registry entry does not exist' do
            it 'returns true' do
              expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                message: "out-of-date", reason: "registry doesn't exist"))

              expect(described_class.repository_out_of_date?(model_record_id)).to be_truthy
            end
          end

          context 'when project_repository_registry entry does exist' do
            context 'when last_repository_updated_at is not set' do
              it 'returns false' do
                registry = create(:geo_project_repository_registry, :synced, model_record_key => model_record)
                update_last_repository_updated_at(nil)

                expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                  message: "up-to-date", reason: "there is no timestamp for the latest change to the repo"))

                expect(described_class.repository_out_of_date?(registry_project_id(registry))).to be_falsey
              end
            end

            context 'when synchronous_request_required is true' do
              let(:model_record) { create_model_record_with_pipeline_refs }
              let(:registry) do
                create(:geo_project_repository_registry, :verification_succeeded, model_record_key => model_record)
              end

              let(:secondary_pipeline_refs) { Array.new(10) { |x| "refs/pipelines/#{x}" } }
              let(:some_secondary_pipeline_refs) { Array.new(9) { |x| "refs/pipelines/#{x}" } }

              context 'when the primary has pipeline refs the secondary does not have' do
                let(:model_record) { create_model_record_with_pipeline_refs(9) }

                it 'returns true' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry_project_id(registry)).and_return(secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "secondary is missing pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry), true)).to be_truthy
                end
              end

              context 'when the secondary has pipeline refs the primary does not have' do
                it 'returns false' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry_project_id(registry)).and_return(some_secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "secondary has all pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry), true)).to be_falsey
                end
              end

              context 'when pipeline refs are the same on primary and secondary' do
                it 'returns false' do
                  allow(::Gitlab::Geo).to receive(:primary_pipeline_refs)
                    .with(registry_project_id(registry)).and_return(secondary_pipeline_refs)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "secondary has all pipeline refs"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry), true)).to be_falsey
                end
              end
            end

            context 'when last_repository_updated_at is set' do
              context 'when sync failed' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, :failed, model_record_key => model_record)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "sync failed"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry))).to be_truthy
                end
              end

              context 'when last_synced_at is not set' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, model_record_key => model_record,
                    last_synced_at: nil)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "it has never been synced"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry))).to be_truthy
                end
              end

              context 'when verification failed' do
                it 'returns true' do
                  registry = create(:geo_project_repository_registry, :verification_failed,
                    model_record_key => model_record)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "out-of-date", reason: "not verified yet"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry))).to be_truthy
                end
              end

              context 'when verification succeeded' do
                it 'returns false' do
                  registry = create(:geo_project_repository_registry, :verification_succeeded,
                    model_record_key => model_record, last_synced_at: Time.current + 5.minutes)

                  expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(
                    message: "up-to-date", reason: "last successfully synced after latest change"))

                  expect(described_class.repository_out_of_date?(registry_project_id(registry))).to be_falsey
                end
              end

              context 'when last_synced_at is set', :freeze_time do
                using RSpec::Parameterized::TableSyntax

                where(:project_last_updated, :project_registry_last_synced, :expected) do
                  Time.current               | (Time.current - 1.minute)  | true
                  (Time.current - 2.minutes) | (Time.current - 1.minute)  | false
                  (Time.current - 3.minutes) | (Time.current - 1.minute)  | false
                  (Time.current - 3.minutes) | (Time.current - 5.minutes) | true
                end

                with_them do
                  before do
                    update_last_repository_updated_at(project_last_updated)

                    create(:geo_project_repository_registry, :verification_succeeded,
                      model_record_key => model_record, last_synced_at: project_registry_last_synced)
                  end

                  it 'returns the expected value' do
                    message = expected ? 'out-of-date' : 'up-to-date'

                    expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(message: message))
                    expect(described_class.repository_out_of_date?(model_record_id)).to eq(expected)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
