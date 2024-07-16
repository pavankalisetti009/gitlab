# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EpicsController, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_epics_path(group) }

    context 'when work_item_epics_rollout enabled' do
      before do
        stub_feature_flags(work_item_epics_rollout: user, namespace_level_work_items: false, work_item_epics: true)
      end

      it 'renders with feature flag enabled' do
        get_index

        expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: true)
      end
    end

    context 'when work_item_epics_rollout disabled' do
      before do
        stub_feature_flags(work_item_epics_rollout: false, namespace_level_work_items: false)
      end

      it 'renders with feature flag disabled' do
        get_index

        expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: false)
      end
    end

    context 'when work_item_epics disabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
      end

      it 'returns not found' do
        get_index

        expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: false)
      end
    end
  end

  describe 'GET #show' do
    context 'for summarize notes feature' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :summarize_comments, epic).and_return(summarize_notes_enabled)
      end

      context 'when feature is available set' do
        let(:summarize_notes_enabled) { true }

        it 'exposes the required feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end

      context 'when feature is not available' do
        let(:summarize_notes_enabled) { false }

        it 'does not expose the feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).not_to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end
    end
  end
end
