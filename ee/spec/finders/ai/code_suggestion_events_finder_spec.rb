# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionEventsFinder, :click_house, feature_category: :value_stream_management do
  let_it_be(:organization) { create :organization, :default }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user_contributor_1) { create(:user) }
  let_it_be(:user_contributor_2) { create(:user) }
  let_it_be(:user_contributor_only_on_ch) { create(:user) }
  let_it_be(:user_not_contributor) { create(:user) }
  let_it_be(:code_suggestion_event_1) { create(:ai_code_suggestion_event, :shown, user: user_contributor_1) }
  let_it_be(:code_suggestion_event_2) { create(:ai_code_suggestion_event, :shown, user: user_contributor_2) }
  let_it_be(:code_suggestion_event_3) { create(:ai_code_suggestion_event, :accepted, user: user_not_contributor) }
  let_it_be(:code_suggestion_event_4) do
    create(:ai_code_suggestion_event, :accepted, user: user_contributor_only_on_ch)
  end

  subject(:results) { described_class.new(user, resource: group).execute }

  describe '#execute' do
    context 'when user cannot see code suggestion events' do
      let_it_be(:user) { create(:user, :with_self_managed_duo_enterprise_seat) }

      before_all do
        group.add_guest(user)
      end

      it 'returns an empty relation' do
        expect(results).to be_empty
      end
    end

    context 'when user can see code suggestion events' do
      let_it_be(:user) { create(:user, :with_self_managed_duo_enterprise_seat) }
      let_it_be(:event_1) do
        create(:event, :pushed, project: project, author: user_contributor_1, created_at: 3.days.ago)
      end

      let_it_be(:event_2) do
        create(:event, :pushed, project: project, author: user_contributor_2, created_at: 1.day.ago)
      end

      let_it_be(:event_3) do
        create(:event, :pushed, project: project, author: user_contributor_only_on_ch, created_at: 1.month.ago)
      end

      let_it_be(:event_4) do
        create(:event, :created, :for_issue, project: project, author: user_not_contributor, created_at: 1.day.ago)
      end

      before_all do
        group.add_reporter(user)
      end

      shared_examples 'fetch code suggestion events' do |flag_enabled|
        before do
          stub_feature_flags(fetch_contributions_data_from_new_tables: flag_enabled)
        end

        it 'returns correct results' do
          if Gitlab::ClickHouse.enabled_for_analytics?
            expect(ClickHouse::Client).to receive(:select).and_call_original
          else
            expect(ClickHouse::Client).not_to receive(:select)
          end

          expect(results).to match_array(expected_suggestion_events)
        end
      end

      context 'and CH is enabled', :click_house do
        before do
          allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
          insert_events_into_click_house
        end

        let(:expected_suggestion_events) do
          [code_suggestion_event_1, code_suggestion_event_2, code_suggestion_event_4]
        end

        it_behaves_like 'fetch code suggestion events', true

        context 'when fetch_contributions_data_from_new_tables is disabled' do
          it_behaves_like 'fetch code suggestion events', false
        end
      end

      context 'and CH is disabled' do
        it_behaves_like 'fetch code suggestion events' do
          let(:expected_suggestion_events) do
            [code_suggestion_event_1, code_suggestion_event_2]
          end
        end
      end
    end
  end
end
