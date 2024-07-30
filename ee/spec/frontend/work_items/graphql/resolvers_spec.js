import createMockApollo from 'helpers/mock_apollo_helper';
import { updateNewWorkItemCache } from '~/work_items/graphql/resolvers';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import {
  WIDGET_TYPE_COLOR,
  WIDGET_TYPE_ROLLEDUP_DATES,
  WIDGET_TYPE_HEALTH_STATUS,
  CLEAR_VALUE,
} from '~/work_items/constants';
import { createWorkItemQueryResponse } from 'jest/work_items/mock_data';

describe('work items graphql resolvers', () => {
  describe('updateNewWorkItemCache', () => {
    let mockApolloClient;

    const fullPath = 'fullPath';
    const fullPathWithId = 'fullPath-issue-id';
    const iid = 'new-work-item-iid';

    const mutate = (input) => {
      mockApolloClient.mutate({
        mutation: updateNewWorkItemMutation,
        variables: {
          input: {
            workItemType: 'issue',
            fullPath,
            ...input,
          },
        },
      });
    };

    const query = async (widgetName = null) => {
      const queryResult = await mockApolloClient.query({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid },
      });

      if (widgetName == null) return queryResult.data.workspace.workItem;

      return queryResult.data.workspace.workItem.widgets.find(({ type }) => type === widgetName);
    };

    beforeEach(() => {
      const mockApollo = createMockApollo([], {
        Mutation: {
          updateNewWorkItem(_, { input }, { cache }) {
            updateNewWorkItemCache(input, cache);
          },
        },
      });
      mockApollo.clients.defaultClient.cache.writeQuery({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid },
        data: createWorkItemQueryResponse.data,
      });
      mockApolloClient = mockApollo.clients.defaultClient;
    });

    describe('with healthStatus input', () => {
      it('updates health status', async () => {
        await mutate({ healthStatus: 'onTrack' });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: 'onTrack' });
      });

      it('clears health status', async () => {
        await mutate({ healthStatus: CLEAR_VALUE });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: null });
      });
    });

    describe('with color input', () => {
      it('updates color', async () => {
        await mutate({ color: '#000' });

        const queryResult = await query(WIDGET_TYPE_COLOR);
        expect(queryResult).toMatchObject({ color: '#000' });
      });
    });

    describe('with rolledUpDates input', () => {
      it('updates rolledUpDates', async () => {
        await mutate({
          rolledUpDates: {
            dueDateIsFixed: true,
            startDateIsFixed: true,
            dueDateFixed: new Date(2024, 1, 2),
            startDateFixed: new Date(2023, 11, 22),
          },
        });

        const queryResult = await query(WIDGET_TYPE_ROLLEDUP_DATES);
        expect(queryResult).toMatchObject({
          dueDate: '2024-02-02',
          dueDateFixed: '2024-02-02',
          dueDateIsFixed: true,
          startDate: '2023-12-22',
          startDateFixed: '2023-12-22',
          startDateIsFixed: true,
        });
      });
    });
  });
});
