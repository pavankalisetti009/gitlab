# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Lifecycle, feature_category: :team_planning do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: namespace) }
  let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: namespace) }
  let_it_be(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: namespace) }

  subject(:custom_lifecycle) do
    build(:work_item_custom_lifecycle,
      namespace: namespace,
      default_open_status: open_status,
      default_closed_status: closed_status,
      default_duplicate_status: duplicate_status
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:default_open_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_closed_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_duplicate_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:statuses).through(:lifecycle_statuses) }
    it { is_expected.to have_many(:type_custom_lifecycles) }
    it { is_expected.to have_many(:work_item_types).through(:type_custom_lifecycles) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:default_open_status) }
    it { is_expected.to validate_presence_of(:default_closed_status) }
    it { is_expected.to validate_presence_of(:default_duplicate_status) }

    context 'with uniqueness validations' do
      subject(:custom_lifecycle) { create(:work_item_custom_lifecycle) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    end

    describe '#validate_default_status_categories' do
      context 'with invalid category combinations' do
        it 'is invalid when default_open_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: closed_status,
            default_closed_status: closed_status,
            default_duplicate_status: duplicate_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_open_status])
            .to include(/must be of category triage or to_do or in_progress/)
        end

        it 'is invalid when default_closed_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: open_status,
            default_closed_status: open_status,
            default_duplicate_status: duplicate_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_closed_status]).to include(/must be of category done or cancelled/)
        end

        it 'is invalid when default_duplicate_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: open_status,
            default_closed_status: closed_status,
            default_duplicate_status: open_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_duplicate_status]).to include(/must be of category done or cancelled/)
        end
      end
    end
  end

  describe 'callbacks' do
    describe '#ensure_default_statuses_in_lifecycle' do
      context 'when creating a new lifecycle' do
        it 'automatically adds default statuses to the lifecycle statuses' do
          expect { custom_lifecycle.save! }.to change { custom_lifecycle.statuses.count }.from(0).to(3)

          expect(custom_lifecycle.statuses).to include(open_status)
          expect(custom_lifecycle.statuses).to include(closed_status)
          expect(custom_lifecycle.statuses).to include(duplicate_status)
        end
      end

      context 'when updating an existing lifecycle' do
        let_it_be(:new_open_status) do
          create(:work_item_custom_status, :open, name: "Ready for development", namespace: namespace)
        end

        before do
          custom_lifecycle.save!
        end

        it 'adds new default statuses to the lifecycle statuses' do
          expect do
            custom_lifecycle.update!(default_open_status: new_open_status)
          end.to change { custom_lifecycle.statuses.count }.by(1)

          expect(custom_lifecycle.statuses).to include(new_open_status)
          expect(custom_lifecycle.statuses).to include(closed_status)
          expect(custom_lifecycle.statuses).to include(duplicate_status)
        end

        it 'does not duplicate statuses already in the collection' do
          expect do
            custom_lifecycle.update!(default_open_status: open_status)
          end.not_to change { custom_lifecycle.statuses.count }
        end
      end
    end
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
  end
end
