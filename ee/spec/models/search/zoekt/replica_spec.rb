# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Replica, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:replicas) }
    it { is_expected.to have_many(:indices).inverse_of(:replica) }
  end

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      expect(zoekt_replica).to be_valid
      zoekt_replica.namespace_id = zoekt_replica.namespace_id.next
      expect(zoekt_replica).to be_invalid
    end

    describe 'project_can_not_assigned_to_same_replica_unless_index_is_reallocating' do
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:zoekt_index) do
        create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace)
      end

      let_it_be(:zoekt_repository) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index) }

      context 'when a project is assigned to the two indices in the same replica' do
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace)
        end

        let_it_be(:zoekt_repository2) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index2) }

        context 'when one index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :reallocating)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
          end
        end

        context 'when no index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :ready)
          end

          it 'is invalid' do
            expect { zoekt_replica.validate! }.to raise_error(ActiveRecord::RecordInvalid,
              /A project can not be assigned to the same replica unless the index is being reallocated/)
          end
        end
      end

      context 'when a project is assigned to the two indices in the different replica' do
        let_it_be(:zoekt_replica2) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, replica: zoekt_replica2, zoekt_enabled_namespace: zoekt_enabled_namespace)
        end

        context 'when one index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :reallocating)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
            expect(zoekt_replica2).to be_valid
          end
        end

        context 'when no index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :ready)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
            expect(zoekt_replica2).to be_valid
          end
        end
      end
    end
  end

  describe '.for_enabled_namespace!' do
    context 'when a replica exists for that namespace' do
      it 'returns that replica' do
        expect(described_class.for_enabled_namespace!(zoekt_enabled_namespace)).to eq(zoekt_replica)
      end
    end

    context 'when a replica does not exist for that namespace' do
      it 'returns a new replica that is associated with that namespaces' do
        another_namespace = create(:group)
        another_enabled_namespace = create(:zoekt_enabled_namespace, namespace: another_namespace)

        replica = described_class.for_enabled_namespace!(another_enabled_namespace)
        expect(replica.zoekt_enabled_namespace).to eq(another_enabled_namespace)
        expect(replica.namespace_id).to eq(another_namespace.id)
      end

      context 'and a uniqueness conflict occurs' do
        it 'retries the method again' do
          raise_exception = true

          expect(described_class).to receive(:where).with(namespace_id: namespace.id).twice do
            if raise_exception
              raise_exception = false
              raise ActiveRecord::RecordInvalid.new(
                described_class.new.tap do |r|
                  r.errors.add(:namespace_id, :taken)
                end
              ), "Record is invalid"
            else
              zoekt_enabled_namespace.replicas
            end
          end

          expect(described_class.for_enabled_namespace!(zoekt_enabled_namespace)).to eq(zoekt_replica)
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be_with_reload(:replica_1_idx_1) do
      create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_replica.zoekt_enabled_namespace)
    end

    let_it_be_with_reload(:replica_1_idx_2) do
      create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_replica.zoekt_enabled_namespace)
    end

    describe '.with_all_ready_indices' do
      subject(:scope) { described_class.with_all_ready_indices }

      it 'returns replicas where all their indices are marked as ready' do
        replica_1_idx_1.ready!
        replica_1_idx_2.pending!

        expect(scope).to be_empty

        replica_1_idx_2.ready!
        expect(scope).to match_array(zoekt_replica)
      end
    end

    describe '.with_non_ready_indices' do
      subject(:scope) { described_class.with_non_ready_indices }

      it 'returns replicas that have at least one index that is not ready' do
        replica_1_idx_1.ready!
        replica_1_idx_2.ready!

        expect(scope).to be_empty

        replica_1_idx_2.pending!
        expect(scope).to match_array(zoekt_replica)
      end
    end

    describe '.for_namespace' do
      before do
        create(:zoekt_replica)
      end

      it 'returns replicas for the given namespace' do
        expect(described_class.for_namespace(namespace.id).pluck(:namespace_id).uniq).to contain_exactly(namespace.id)
      end
    end
  end

  describe '#fetch_repositories_with_project_identifier' do
    let_it_be(:project) { create(:project) }

    let_it_be_with_reload(:replica_1_idx_1) do
      create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_replica.zoekt_enabled_namespace,
        state: :ready)
    end

    let_it_be_with_reload(:replica_1_idx_2) do
      create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_replica.zoekt_enabled_namespace,
        state: :reallocating)
    end

    let_it_be_with_reload(:repo_1_ready) do
      create(:zoekt_repository, project: project, zoekt_index: replica_1_idx_1, state: :ready)
    end

    let_it_be_with_reload(:repo_2_pending) do
      create(:zoekt_repository, project: project, zoekt_index: replica_1_idx_2, state: :pending)
    end

    it 'returns the ready repositories for that replica and project id' do
      expect(zoekt_replica.fetch_repositories_with_project_identifier(project.id)).to match_array([repo_1_ready])
    end
  end
end
