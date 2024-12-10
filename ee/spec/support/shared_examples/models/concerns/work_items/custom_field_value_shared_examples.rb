# frozen_string_literal: true

RSpec.shared_examples 'a work item custom field value' do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item) }
    it { is_expected.to validate_presence_of(:custom_field) }

    describe '#copy_namespace_from_work_item' do
      let(:work_item) { create(:work_item) }

      it 'copies namespace_id from the associated work item' do
        expect do
          subject.work_item = work_item
          subject.valid?
        end.to change { subject.namespace_id }.from(nil).to(work_item.namespace_id)
      end
    end
  end
end
