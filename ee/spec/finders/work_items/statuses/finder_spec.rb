# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Finder, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_custom_status) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: other_group) }
  let(:namespace) { group }

  describe '#execute' do
    subject(:finder) { described_class.new(namespace, params).execute }

    shared_examples 'returns system-defined status' do
      it 'returns system-defined status' do
        expect(finder).to be_a(WorkItems::Statuses::SystemDefined::Status)
        expect(finder.id).to eq(1)
      end
    end

    shared_examples 'returns custom status' do
      it 'returns custom status' do
        expect(finder).to eq(custom_status)
      end
    end

    shared_examples 'returns nil' do
      it 'returns nil' do
        expect(finder).to be_nil
      end
    end

    context 'with system_defined_status_identifier param' do
      let(:params) { { 'system_defined_status_identifier' => 1 } }

      it_behaves_like 'returns system-defined status'

      context 'when status is not found' do
        let(:params) { { 'system_defined_status_identifier' => 999 } }

        it_behaves_like 'returns nil'
      end
    end

    context 'with custom_status_id param' do
      let_it_be(:custom_status) { create(:work_item_custom_status, namespace: group) }
      let(:params) { { 'custom_status_id' => custom_status.id } }

      it_behaves_like 'returns custom status'

      context 'when status is not found' do
        let(:params) { { 'custom_status_id' => other_custom_status.id } }

        it_behaves_like 'returns nil'
      end
    end

    context 'with name param' do
      let(:params) { { 'name' => 'To do' } }

      context 'when namespace has custom statuses' do
        let_it_be(:custom_status) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group) }

        it_behaves_like 'returns custom status'

        context 'when name has surrounding quotes' do
          let(:params) { { 'name' => '"To do"' } }

          it_behaves_like 'returns custom status'
        end

        context 'when status contains emojis' do
          let_it_be(:custom_status_with_emoji) do
            create(:work_item_custom_status, :to_do, name: '🐞🧨', namespace: group)
          end

          let(:params) { { 'name' => '🐞🧨' } }

          it 'returns the emoji status' do
            expect(finder).to eq(custom_status_with_emoji)
          end

          context 'when name has surrounding quotes' do
            let(:params) { { 'name' => '"🐞🧨"' } }

            it 'returns the emoji status' do
              expect(finder).to eq(custom_status_with_emoji)
            end
          end
        end

        context 'when name has double surrounding quotes' do
          let(:params) { { 'name' => '""To do""' } }

          it_behaves_like 'returns nil' # because "To do" doesn't exist
        end

        context 'when status only exists as system-defined' do
          let(:params) { { 'name' => 'Done' } }

          it_behaves_like 'returns nil'
        end

        context 'when status is not found' do
          let(:params) { { 'name' => 'Invalid' } }

          it_behaves_like 'returns nil'
        end
      end

      context 'when namespace has no custom statuses' do
        it_behaves_like 'returns system-defined status'

        context 'when status is not found' do
          let(:params) { { 'name' => 'Invalid' } }

          it_behaves_like 'returns nil'
        end
      end
    end

    context 'with no status params' do
      let(:params) { {} }

      it_behaves_like 'returns nil'
    end
  end
end
