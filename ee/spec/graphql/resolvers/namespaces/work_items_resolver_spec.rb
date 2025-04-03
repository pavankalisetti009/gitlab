# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Namespaces::WorkItemsResolver, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group)        { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::WorkItemType.connection_type)
  end

  context 'with a group' do
    let_it_be(:group_work_item1) do
      create(:work_item, :group_level, :epic, namespace: group)
    end

    let_it_be(:group_work_item2) do
      create(:work_item, :group_level, :epic, namespace: group)
    end

    def resolve_items(args = {}, context = { current_user: current_user })
      resolve(described_class, obj: group, args: args, ctx: context, arg_style: :internal)
    end

    def perform_with_timeframe(timeframe: { start: '2020-08-12', end: '2020-08-14' })
      resolve_items(timeframe: timeframe)
    end

    context 'when namespace level work items are enabled' do
      before do
        stub_feature_flags(namespace_level_work_items: true, work_item_epics: true)
        stub_licensed_features(epics: true)
      end

      context 'with timeframe filtering' do
        it 'does not return work items without a dates source' do
          expect(perform_with_timeframe).to be_empty
        end

        it 'raises an error if the timeframe exceeds 3.5 years' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
            'Timeframe cannot exceed 3.5 years for work item queries') do
            perform_with_timeframe(timeframe: { start: '2020-01-01', end: '2023-08-01' })
          end
        end

        context 'when work item start and due dates are both present' do
          let_it_be(:date_source1) do
            create(:work_items_dates_source, work_item: group_work_item1, start_date: '2020-08-13',
              due_date: '2020-08-15')
          end

          let_it_be(:date_source2) do
            create(:work_items_dates_source, work_item: group_work_item2, start_date: '2020-08-16',
              due_date: '2020-08-20')
          end

          it 'returns only work items within timeframe' do
            expect(perform_with_timeframe).to contain_exactly(group_work_item1)
          end
        end

        context 'when only start date or due date is present' do
          let_it_be(:date_source_only_start) do
            create(:work_items_dates_source, work_item: group_work_item1, start_date: '2020-08-12', due_date: nil)
          end

          let_it_be(:date_source_only_due) do
            create(:work_items_dates_source, work_item: group_work_item2, start_date: nil, due_date: '2020-08-14')
          end

          it 'returns only work items within timeframe' do
            expect(perform_with_timeframe).to contain_exactly(group_work_item1, group_work_item2)
          end
        end
      end
    end
  end
end
