import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import StatusLifecycleModal from 'ee/groups/settings/work_items/status_modal.vue';
import StatusForm from 'ee/groups/settings/work_items/status_form.vue';
import lifecycleUpdateMutation from 'ee/groups/settings/work_items/lifecycle_update.mutation.graphql';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('StatusLifecycleModal', () => {
  let wrapper;
  let mockApollo;

  const mockLifecycle = {
    id: 'gid://gitlab/WorkItems::Lifecycle/1',
    name: 'Lifecycle 1',
    workItemTypes: [
      {
        id: 'gid://gitlab/WorkItems::Type/1',
        name: 'Issue',
        iconName: 'issue-type-issue',
        __typename: 'WorkItemType',
      },
      {
        id: 'gid://gitlab/WorkItems::Type/2',
        name: 'Task',
        iconName: 'issue-type-task',
        __typename: 'WorkItemType',
      },
    ],
    statuses: [
      {
        id: 'status-1',
        name: 'Open',
        color: '#1f75cb',
        iconName: 'status-waiting',
        description: 'New issues',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'status-2',
        name: 'In Progress',
        color: '#1f75cb',
        iconName: 'status-running',
        description: '',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'status-3',
        name: 'Done',
        color: '#108548',
        iconName: 'status-success',
        description: 'Completed work',
        __typename: 'WorkItemStatus',
      },
    ],
    defaultOpenStatus: {
      id: 'status-1',
      name: 'Open',
    },
    defaultClosedStatus: {
      id: 'status-3',
      name: 'Done',
    },
    defaultDuplicateStatus: {
      id: 'status-3',
      name: 'Done',
    },
  };

  const mockUpdateResponse = {
    data: {
      lifecycleUpdate: {
        lifecycle: {
          ...mockLifecycle,
          statuses: [
            ...mockLifecycle.statuses,
            {
              id: 'status-4',
              name: 'New Status',
              color: '#ff0000',
              iconName: 'status-neutral',
              description: '',
              __typename: 'WorkItemStatus',
            },
          ],
          __typename: 'WorkItemLifecycle',
        },
        __typename: 'LifecycleUpdatePayload',
        errors: [],
      },
    },
  };

  const newFormData = {
    name: 'Updated Name',
    color: '#00ff00',
    description: 'Updated description',
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findStatusInfo = () => wrapper.findByTestId('status-info-alert');
  const findCategorySection = (category) => wrapper.findByTestId(`category-${category}`);
  const findStatusBadges = () => wrapper.findAllByTestId('status-badge');
  const findDefaultStatusBadges = () => wrapper.findAllByTestId('default-status-badge');
  const findStatusForm = () => wrapper.findComponent(StatusForm);
  const findEditStatusButton = (statusId) => wrapper.findByTestId(`edit-status-${statusId}`);
  const findErrorMessage = () => wrapper.findByTestId('error-alert');

  const updateLifecycleHandler = jest.fn().mockResolvedValue(mockUpdateResponse);

  const addStatus = async (save = true) => {
    const addButton = findCategorySection('triage').find('[data-testid="add-status-button"]');
    addButton.vm.$emit('click');
    await nextTick();

    findStatusForm().vm.$emit('update', newFormData);
    await nextTick();

    if (save) {
      findStatusForm().vm.$emit('save');
    }
  };

  const createComponent = ({
    props = {},
    lifecycle = mockLifecycle,
    updateHandler = updateLifecycleHandler,
  } = {}) => {
    mockApollo = createMockApollo([[lifecycleUpdateMutation, updateHandler]]);

    wrapper = shallowMountExtended(StatusLifecycleModal, {
      apolloProvider: mockApollo,
      propsData: {
        visible: true,
        lifecycle,
        fullPath: 'group/project',
        ...props,
      },
      stubs: {
        GlModal,
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    // Mock gon for suggested colors
    global.gon = {
      suggested_label_colors: {
        '#FF0000': 'Red',
        '#00FF00': 'Green',
        '#0000FF': 'Blue',
      },
    };
  });

  describe('initial rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays modal when visible prop is true', () => {
      expect(findModal().props('visible')).toBe(true);
    });

    it('shows status info alert with work item types', () => {
      expect(findStatusInfo().exists()).toBe(true);
      expect(findStatusInfo().text()).toContain('Issue');
      expect(findStatusInfo().text()).toContain('Task');
    });

    it('displays statuses grouped by category', () => {
      expect(findCategorySection('to_do')).toBeDefined();
      expect(findCategorySection('in_progress')).toBeDefined();
      expect(findCategorySection('done')).toBeDefined();
      expect(findStatusBadges()).toHaveLength(3);
    });

    it('shows default status badges for default statuses', () => {
      const badges = findDefaultStatusBadges();
      expect(badges).toHaveLength(2);
      expect(badges.at(0).text()).toBe('Open default');
      expect(badges.at(1).text()).toBe('Closed default');
    });

    it('shows add status buttons for each category', () => {
      const categories = ['triage', 'to_do', 'in_progress', 'done', 'cancelled'];
      categories.forEach((category) => {
        const section = findCategorySection(category);
        expect(section.find('[data-testid="add-status-button"]').exists()).toBe(true);
      });
    });
  });

  describe('modal visibility', () => {
    it('emits close event when modal is hidden', () => {
      createComponent();

      findModal().vm.$emit('hide');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('hides modal when visible prop is false', () => {
      createComponent({ props: { visible: false } });

      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('adding status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows inline form when add status button is clicked', async () => {
      const addButton = findCategorySection('triage').find('[data-testid="add-status-button"]');

      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);
      expect(findStatusForm().props('isEditing')).toBe(false);
    });

    it('pre-fills color based on category when adding status', async () => {
      const addButton = findCategorySection('done').find('[data-testid="add-status-button"]');

      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().props().formData.color).toBe('#108548'); // DONE category color
    });

    it('cancels add form when cancel event is emitted', async () => {
      const addButton = findCategorySection('triage').find('[data-testid="add-status-button"]');
      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);

      findStatusForm().vm.$emit('cancel');
      await nextTick();

      expect(findStatusForm().exists()).toBe(false);
    });
  });

  describe('editing status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows inline edit form when edit button is clicked', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);
      expect(findStatusForm().props('isEditing')).toBe(true);
    });

    it('pre-fills form with existing status data when editing', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      expect(findStatusForm().props().formData).toEqual({
        name: 'Open',
        color: '#1f75cb',
        description: 'New issues',
      });
    });

    it('passes correct form data to inline form component', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      const inlineForm = findStatusForm();
      expect(inlineForm.props('formData')).toEqual({
        name: 'Open',
        color: '#1f75cb',
        description: 'New issues',
      });
    });
  });

  describe('form handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('updates form data when inline form emits update event', async () => {
      await addStatus(false);

      expect(findStatusForm().props().formData).toEqual(newFormData);
    });

    it('calls the update handler when adding status', async () => {
      await addStatus();
      expect(updateLifecycleHandler).toHaveBeenCalled();
    });

    it('does not call the update handler when adding more than 30 statuses and shows error', async () => {
      const limitStatuses = [];

      for (let i = 0; i < 30; i += 1) {
        limitStatuses.push({
          id: `status-${i + 1}`,
          name: `Status-${i}`,
          color: '#ff0000',
          iconName: 'status-neutral',
          description: '',
          __typename: 'WorkItemStatus',
        });
      }

      const mockLimitLifecycle = {
        ...mockLifecycle,
        statuses: limitStatuses,
      };

      const mockLimitStatusResponse = {
        data: {
          lifecycleUpdate: {
            lifecycle: {
              ...mockLimitLifecycle,
              __typename: 'WorkItemLifecycle',
            },
            __typename: 'LifecycleUpdatePayload',
            errors: [],
          },
        },
      };

      const limitReachedHandler = jest.fn().mockResolvedValue(mockLimitStatusResponse);

      createComponent({ updateHandler: limitReachedHandler, lifecycle: mockLimitLifecycle });

      expect(findErrorMessage().exists()).toBe(false);

      await addStatus();

      expect(updateLifecycleHandler).not.toHaveBeenCalled();
      expect(findErrorMessage().exists()).toBe(true);
    });
  });
});
