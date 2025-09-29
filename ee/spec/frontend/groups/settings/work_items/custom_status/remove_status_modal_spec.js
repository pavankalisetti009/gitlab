import { GlAlert, GlModal, GlIcon } from '@gitlab/ui';
import { cloneDeep } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import lifecycleUpdateMutation from 'ee/groups/settings/work_items/custom_status/graphql/lifecycle_update.mutation.graphql';
import RemoveStatusModal from 'ee/groups/settings/work_items/custom_status/remove_status_modal.vue';
import RemoveStatusModalListbox from 'ee/groups/settings/work_items/custom_status/remove_status_modal_listbox.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockLifecycles } from '../mock_data';

Vue.use(VueApollo);

describe('RemoveStatusModal', () => {
  let wrapper;

  const mockUpdateResponse = {
    data: {
      lifecycleUpdate: {
        lifecycle: mockLifecycles[0],
        errors: [],
        __typename: 'LifecycleUpdatePayload',
      },
    },
  };

  const lifecycleUpdateMutationHandler = jest.fn().mockResolvedValue(mockUpdateResponse);

  const findModal = () => wrapper.findComponent(GlModal);
  const findCurrentStatus = () => wrapper.findByTestId('current-status-value');
  const findNewStatusLabel = () => wrapper.find('label');
  const findNewStatusListbox = () => wrapper.findComponent(RemoveStatusModalListbox);
  const findNewDefaultLabel = () => wrapper.findByTestId('new-default-label');
  const findNewDefaultListbox = () => wrapper.findByTestId('new-default-listbox');

  const createComponent = ({ props = {}, updateHandler = lifecycleUpdateMutationHandler } = {}) => {
    wrapper = shallowMountExtended(RemoveStatusModal, {
      apolloProvider: createMockApollo([[lifecycleUpdateMutation, updateHandler]]),
      propsData: {
        fullPath: 'full/path',
        lifecycle: mockLifecycles[0],
        statusToRemove: mockLifecycles[0].statuses[0],
        ...props,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct title', () => {
      expect(findModal().props('title')).toBe('Remove status');
    });

    it('emits hidden event when modal is hidden', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hidden')).toEqual([[]]);
    });

    it('renders "new status" body text', () => {
      expect(wrapper.text()).toContain(
        `0 items currently use the status 'Karon Homenick'. Select a new status for these items.`,
      );
    });

    it('renders the current status details', () => {
      expect(findCurrentStatus().findComponent(GlIcon).props('name')).toBe('status-waiting');
      expect(findCurrentStatus().findComponent(GlIcon).attributes('style')).toBe(
        'color: rgb(115, 114, 120);',
      );
      expect(findCurrentStatus().text()).toBe('Karon Homenick');
    });
  });

  it('renders the new status selection label', () => {
    createComponent();

    expect(findNewStatusLabel().text()).toBe('New status');
  });

  it('filters listbox items to remove statusToRemove and keep statuses from same open/closed state', () => {
    const expectedStatus = {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/199',
      name: 'Another open state',
      category: 'to_do',
    };
    const lifecycle = cloneDeep(mockLifecycles[0]);
    lifecycle.statuses.push(expectedStatus);
    createComponent({ props: { lifecycle } });

    expect(findNewStatusListbox().props('items')).toEqual([
      {
        ...expectedStatus,
        text: expectedStatus.name,
        value: expectedStatus.id,
      },
    ]);
  });

  it('pre-selects the first available status in the listbox', () => {
    createComponent({ props: { statusToRemove: mockLifecycles[0].statuses[1] } }); // first closed status

    expect(findNewStatusListbox().props('selected')).toBe(mockLifecycles[0].statuses[2]); // second closed status
  });

  it('updates selectedNewStatusId when a new status is selected', async () => {
    createComponent();
    const newSelection = mockLifecycles[0].statuses[2];

    findNewStatusListbox().vm.$emit('input', newSelection.id);
    await nextTick();

    expect(findNewStatusListbox().props('value')).toBe(newSelection.id);
  });

  describe('when default status is selected', () => {
    beforeEach(() => {
      createComponent({ props: { statusToRemove: mockLifecycles[0].statuses[0] } });
    });

    it('renders "new default" body text', () => {
      expect(wrapper.text()).toContain(
        `This status is set as the Open default. Select a new Open default to remove this status.`,
      );
    });

    it('renders the new default selection label', () => {
      expect(findNewDefaultLabel().text()).toBe('Open default');
    });

    it('updates selectedNewDefaultId when a new default is selected', async () => {
      const newSelection = mockLifecycles[0].statuses[2];

      findNewDefaultListbox().vm.$emit('input', newSelection.id);
      await nextTick();

      expect(findNewDefaultListbox().props('value')).toBe(newSelection.id);
    });
  });

  describe('when default status is not selected', () => {
    const statusToRemove = {
      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/199',
      name: 'Another open state',
      category: 'to_do',
    };

    beforeEach(() => {
      createComponent({ props: { statusToRemove } });
    });

    it('does not render "new default" body text', () => {
      expect(wrapper.text()).not.toContain(
        `This status is set as the Open default. Select a new Open default to remove this status.`,
      );
    });

    it('does not render the new default selection label', () => {
      expect(findNewDefaultLabel().exists()).toBe(false);
    });

    it('does not render the new default listbox', () => {
      expect(findNewDefaultListbox().exists()).toBe(false);
    });
  });

  describe('when removing status', () => {
    it('sends mutation to map old status to new status', async () => {
      createComponent();

      findNewStatusListbox().vm.$emit(
        'input',
        'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
      );
      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await nextTick();

      expect(lifecycleUpdateMutationHandler).toHaveBeenCalledWith({
        input: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/37',
          namespacePath: 'full/path',
          statusMappings: [
            {
              newStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
              oldStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
            },
          ],
        },
      });
    });

    it('sends mutation to update to a new default status', async () => {
      createComponent();

      findNewDefaultListbox().vm.$emit(
        'input',
        'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
      );
      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await nextTick();

      expect(lifecycleUpdateMutationHandler).toHaveBeenCalledWith({
        input: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/37',
          namespacePath: 'full/path',
          defaultOpenStatusIndex: 2,
        },
      });
    });

    it('displays an error message if the update fails', async () => {
      const mockErrorUpdateResponse = {
        data: {
          lifecycleUpdate: {
            lifecycle: null,
            errors: ['I am error'],
            __typename: 'LifecycleUpdatePayload',
          },
        },
      };
      createComponent({ updateHandler: jest.fn().mockResolvedValue(mockErrorUpdateResponse) });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.findComponent(GlAlert).text()).toBe('I am error');
    });
  });
});
