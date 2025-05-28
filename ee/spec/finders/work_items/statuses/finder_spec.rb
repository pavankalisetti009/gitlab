# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Finder, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }
  let_it_be(:other_custom_status) { create(:work_item_custom_status, namespace: other_group) }
  let(:namespace) { group }

  describe '#execute' do
    subject(:finder) { described_class.new(namespace, params).execute }

    context 'with system_defined_status_identifier param' do
      let(:params) { { 'system_defined_status_identifier' => 1 } }

      it 'returns the system-defined status' do
        expect(finder).to be_a(WorkItems::Statuses::SystemDefined::Status)
        expect(finder.id).to eq(1)
      end

      context 'when status is not found' do
        let(:params) { { 'system_defined_status_identifier' => 999 } }

        it 'returns nil' do
          expect(finder).to be_nil
        end
      end
    end

    context 'with custom_status_id param' do
      let(:params) { { 'custom_status_id' => custom_status.id } }

      it 'returns the custom status' do
        expect(finder).to eq(custom_status)
      end

      context 'when status is not found' do
        let(:params) { { 'custom_status_id' => other_custom_status.id } }

        it 'returns nil' do
          expect(finder).to be_nil
        end
      end
    end

    context 'with no status params' do
      let(:params) { {} }

      it 'returns nil' do
        expect(finder).to be_nil
      end
    end
  end
end
