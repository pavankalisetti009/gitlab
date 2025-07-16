import { GlForm } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import workItemBulkUpdateMutation from '~/work_items/graphql/list/work_item_bulk_update.mutation.graphql';
import workItemParentQuery from '~/work_items/graphql/list//work_item_parent.query.graphql';
import getAvailableBulkEditWidgets from '~/work_items/graphql/list/get_available_bulk_edit_widgets.query.graphql';
import WorkItemBulkEditSidebar from '~/work_items/components/work_item_bulk_edit/work_item_bulk_edit_sidebar.vue';
import WorkItemBulkEditIteration from 'ee_component/work_items/components/list/work_item_bulk_edit_iteration.vue';
import { WIDGET_TYPE_ITERATION } from '~/work_items/constants';
import {
  workItemParentQueryResponse,
  availableBulkEditWidgetsQueryResponse,
} from '../../mock_data';

Vue.use(VueApollo);

const availableWidgetsWithout = (widgetToExclude) => {
  const widgetNames = availableBulkEditWidgetsQueryResponse.data.namespace.workItemsWidgets.filter(
    (name) => name !== widgetToExclude,
  );
  return {
    data: {
      namespace: {
        ...availableBulkEditWidgetsQueryResponse.data.namespace,
        workItemsWidgets: widgetNames,
      },
    },
  };
};

const advanceApolloTimers = async () => {
  jest.runOnlyPendingTimers();
  await waitForPromises();
};

describe('WorkItemBulkEditSidebar component EE', () => {
  let wrapper;

  const checkedItems = [
    {
      id: 'gid://gitlab/WorkItem/11',
      title: 'Work Item 11',
      workItemType: { id: 'gid://gitlab/WorkItems::Type/8' },
    },
    {
      id: 'gid://gitlab/WorkItem/22',
      title: 'Work Item 22',
      workItemType: { id: 'gid://gitlab/WorkItems::Type/5' },
    },
  ];

  const workItemParentQueryHandler = jest.fn().mockResolvedValue(workItemParentQueryResponse);
  const workItemBulkUpdateHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemBulkUpdate: { updatedWorkItemCount: 1 } } });
  const defaultAvailableWidgetsHandler = jest
    .fn()
    .mockResolvedValue(availableBulkEditWidgetsQueryResponse);

  const createComponent = ({
    provide = {},
    props = {},
    mutationHandler = workItemBulkUpdateHandler,
    availableWidgetsHandler = defaultAvailableWidgetsHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemBulkEditSidebar, {
      apolloProvider: createMockApollo([
        [workItemParentQuery, workItemParentQueryHandler],
        [workItemBulkUpdateMutation, mutationHandler],
        [getAvailableBulkEditWidgets, availableWidgetsHandler],
      ]),
      provide: {
        hasIssuableHealthStatusFeature: true,
        hasIterationsFeature: true,
        ...provide,
      },
      propsData: {
        checkedItems,
        fullPath: 'group/project',
        isGroup: false,
        ...props,
      },
      stubs: {
        WorkItemBulkEditIteration: stubComponent(WorkItemBulkEditIteration),
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findIterationComponent = () => wrapper.findComponent(WorkItemBulkEditIteration);

  describe('when work_items_bulk_edit is enabled', () => {
    it('calls mutation to bulk edit ee attributes', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
      });
      await waitForPromises();

      findIterationComponent().vm.$emit('input', 'gid://gitlab/Iteration/1215');
      findForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
        input: {
          parentId: 'gid://gitlab/Group/1',
          ids: ['gid://gitlab/WorkItem/11', 'gid://gitlab/WorkItem/22'],
          iterationWidget: {
            iterationId: 'gid://gitlab/Iteration/1215',
          },
        },
      });
    });
  });

  describe('"Iteration" component', () => {
    it.each([true, false])('renders depending on isEpicsList prop', (isEpicsList) => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList },
      });

      expect(findIterationComponent().exists()).toBe(!isEpicsList);
    });

    it('updates iteration when "Iteration" component emits "input" event', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
      });

      findIterationComponent().vm.$emit('input', 'gid://gitlab/Iteration/1215');
      await nextTick();

      expect(findIterationComponent().props('value')).toBe('gid://gitlab/Iteration/1215');
    });

    it('enables "Iteration" component when "Iteration" widget is available', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
      });

      await nextTick();
      await advanceApolloTimers();

      expect(findIterationComponent().props('disabled')).toBe(false);
    });

    it('disables "Iteration" component when "Iteration" widget is unavailable', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
        availableWidgetsHandler: jest
          .fn()
          .mockResolvedValue(availableWidgetsWithout(WIDGET_TYPE_ITERATION)),
      });

      await nextTick();
      await advanceApolloTimers();

      expect(findIterationComponent().props('disabled')).toBe(true);
    });
  });
});
