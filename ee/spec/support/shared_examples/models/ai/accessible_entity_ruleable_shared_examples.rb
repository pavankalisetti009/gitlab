# frozen_string_literal: true

RSpec.shared_examples 'accessible entity ruleable' do
  describe 'validations' do
    subject { described_class.new }

    it { is_expected.to validate_presence_of(:through_namespace_id) }
    it { is_expected.to validate_presence_of(:accessible_entity) }
    it { is_expected.to validate_length_of(:accessible_entity).is_at_most(255) }

    describe 'accessible_entity_exists validation' do
      context 'with valid access entity' do
        %w[duo_classic duo_agents duo_flows].each do |entity|
          it "accepts #{entity}" do
            record = described_class.new(
              through_namespace_id: through_namespace.id, accessible_entity: entity
            )
            expect(record.errors[:accessible_entity]).to be_empty
          end
        end
      end

      context 'with invalid access entity' do
        it 'adds error' do
          record = described_class.new(
            through_namespace_id: through_namespace.id, accessible_entity: 'invalid_entity'
          )
          expect(record).not_to be_valid
          expect(record.errors[:accessible_entity]).to include('is not included in the list')
        end
      end
    end
  end

  describe 'BulkInsertSafe inclusion' do
    it 'includes BulkInsertSafe' do
      expect(described_class.included_modules).to include(BulkInsertSafe)
    end
  end
end
