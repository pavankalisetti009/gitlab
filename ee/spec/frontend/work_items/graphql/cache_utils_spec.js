import namespaceWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/group_namespace_work_item_types.query.graphql.json';
import { setNewWorkItemCache } from '~/work_items/graphql/cache_utils';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { apolloProvider } from '~/graphql_shared/issuable_client';

describe('work items graphql cache utils', () => {
  describe('setNewWorkItemCache', () => {
    it('retrieves defaultOpenStatus for status widget', async () => {
      const mockWriteQuery = jest.fn();

      apolloProvider.clients.defaultClient.cache.writeQuery = mockWriteQuery;
      window.gon.current_user_id = 1;

      const workItemTypes =
        namespaceWorkItemTypesQueryResponse.data?.workspace?.workItemTypes?.nodes || [];
      const taskWidgetDefinitions =
        workItemTypes?.find((type) => type.name === 'Task')?.widgetDefinitions || [];
      const statusDefinition = taskWidgetDefinitions.find((item) => {
        return item.type === WIDGET_TYPE_STATUS;
      });

      await setNewWorkItemCache({
        fullPath: 'gitlab-org/gitlab',
        widgetDefinitions: taskWidgetDefinitions,
        workItemType: 'TASK',
        workItemTypeId: 'gid://gitlab/WorkItems::Type/5',
        workItemTypeIconName: 'issue-type-task',
      });

      await waitForPromises();

      expect(mockWriteQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            workspace: expect.objectContaining({
              workItem: expect.objectContaining({
                widgets: expect.arrayContaining([
                  {
                    type: 'STATUS',
                    status: {
                      ...statusDefinition.defaultOpenStatus,
                    },
                    __typename: 'WorkItemWidgetStatus',
                  },
                ]),
              }),
            }),
          }),
        }),
      );
    });
  });
});
