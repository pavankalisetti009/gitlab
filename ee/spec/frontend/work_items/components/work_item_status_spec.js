import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import namespaceWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/namespace_work_item_types.query.graphql.json';
import workItemStatusQuery from 'ee/work_items/graphql/work_item_status.query.graphql';
import WorkItemStatus from 'ee/work_items/components/work_item_status.vue';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  mockWorkItemStatusResponse,
  mockWorkItemNoStatusResponse,
  updateWorkItemMutationResponse,
} from '../mock_data';

describe('WorkItemStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemIid = '1';
  const workItemType = 'Task';
  const workItemId = 'gid://gitlab/WorkItem/1';
  const allowedStatus = namespaceWorkItemTypesQueryResponse.data.workspace.workItemTypes.nodes
    .find((node) => node.name === workItemType)
    .widgetDefinitions?.find((item) => {
      return item.type === 'STATUS';
    })?.allowedStatuses;

  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('dropdownShown');
  };

  const successUpdateWorkItemMutationHandler = jest
    .fn()
    .mockResolvedValue(updateWorkItemMutationResponse);

  const createComponent = ({
    mountFn = shallowMountExtended,
    canUpdate = true,
    status = mockWorkItemStatusResponse,
    workItemTypesHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse),
    mutationHandler = successUpdateWorkItemMutationHandler,
  } = {}) => {
    const workItemStatusResponseHandler = jest.fn().mockResolvedValue(status);

    wrapper = mountFn(WorkItemStatus, {
      apolloProvider: createMockApollo([
        [namespaceWorkItemTypesQuery, workItemTypesHandler],
        [workItemStatusQuery, workItemStatusResponseHandler],
        [updateWorkItemMutation, mutationHandler],
      ]),
      propsData: {
        canUpdate,
        fullPath: 'test-project-path',
        workItemIid,
        workItemType,
        workItemId,
      },
    });
  };

  const createComponentAndShowDropdown = async () => {
    createComponent();
    await waitForPromises();
    showDropdown();
  };

  it('has "Status" label', async () => {
    createComponent();
    await waitForPromises();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe('Status');
  });

  describe('Default text with canUpdate false and status value', () => {
    it('shows None for no status response', async () => {
      createComponent({
        mountFn: mountExtended,
        canUpdate: false,
        status: mockWorkItemNoStatusResponse,
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('None');
      expect(findSidebarDropdownWidget().props('canUpdate')).toBe(false);
    });

    it('shows In progress when status set', async () => {
      createComponent({
        mountFn: mountExtended,
        canUpdate: false,
        status: mockWorkItemStatusResponse,
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('In progress');
      expect(findSidebarDropdownWidget().props('canUpdate')).toBe(false);
    });
  });

  describe('Dropdown options', () => {
    it('calls `namespaceWorkItemTypesHandler` with variables when dropdown is opened', async () => {
      const workItemTypesHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);
      createComponent({ workItemTypesHandler });
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      expect(workItemTypesHandler).toHaveBeenCalledWith({
        fullPath: 'test-project-path',
      });
    });

    it('shows the skeleton loader when the items are being fetched on click', async () => {
      await createComponentAndShowDropdown();

      expect(findSidebarDropdownWidget().props('loading')).toBe(true);
    });

    it('shows the status in dropdown when the items have finished fetching', async () => {
      await createComponentAndShowDropdown();

      await waitForPromises();

      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(allowedStatus.length);
    });

    it('changes the status to the selected status', async () => {
      const mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({ mutationHandler });
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('updateValue', firstStatus.id);
      await nextTick();
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          statusWidget: {
            status: firstStatus.id,
          },
        },
      });

      expect(findSidebarDropdownWidget().props('itemValue')).toBe(firstStatus.id);
    });

    describe('Tracking event', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it('tracks updating the status', async () => {
        createComponent();
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findSidebarDropdownWidget().vm.$emit('updateValue', null);

        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith('work_item_status_updated', {}, undefined);
      });
    });
  });
});
