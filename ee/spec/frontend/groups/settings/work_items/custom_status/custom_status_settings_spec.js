import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import NamespaceLifecycles from 'ee/groups/settings/work_items/custom_status/custom_status_settings.vue';
import StatusModal from 'ee/groups/settings/work_items/custom_status/status_modal.vue';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import CreateLifecycleModal from 'ee/groups/settings/work_items/custom_status/create_lifecycle_modal.vue';
import namespaceStatusesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_lifecycles.query.graphql';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

const mockLifecycles = [
  {
    id: 'gid://gitlab/WorkItems::Lifecycle/1',
    name: 'Development',
    defaultOpenStatus: { id: '1', name: 'Open', __typename: 'WorkItemStatus' },
    defaultClosedStatus: { id: '2', name: 'Closed', __typename: 'WorkItemStatus' },
    defaultDuplicateStatus: { id: '3', name: 'Duplicate', __typename: 'WorkItemStatus' },
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
        id: '1',
        name: 'Open',
        iconName: 'issue-open',
        color: 'green',
        description: '',
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: '2',
        name: 'In Progress',
        iconName: 'progress',
        color: 'blue',
        description: '',
        __typename: 'WorkItemStatus',
        category: 'in_progress',
      },
      {
        id: '3',
        name: 'Closed',
        iconName: 'issue-close',
        color: 'gray',
        description: '',
        __typename: 'WorkItemStatus',
        category: 'done',
      },
    ],
  },
  {
    id: 'gid://gitlab/WorkItems::Lifecycle/2',
    name: 'Operations',
    defaultOpenStatus: { id: '4', name: 'New', __typename: 'WorkItemStatus' },
    defaultClosedStatus: { id: '5', name: 'Resolved', __typename: 'WorkItemStatus' },
    defaultDuplicateStatus: { id: '6', name: 'Duplicate', __typename: 'WorkItemStatus' },
    workItemTypes: [
      {
        id: 'gid://gitlab/WorkItems::Type/3',
        name: 'Incident',
        iconName: 'issue-type-incident',
        __typename: 'WorkItemType',
      },
    ],
    statuses: [
      {
        id: '4',
        name: 'New',
        iconName: 'issue-new',
        color: 'red',
        description: '',
        category: 'to_do',
        __typename: 'WorkItemStatus',
      },
      {
        id: '5',
        name: 'Resolved',
        iconName: 'check',
        color: 'green',
        description: '',
        category: 'done',
        __typename: 'WorkItemStatus',
      },
    ],
  },
];

describe('CustomStatusSettings', () => {
  let wrapper;
  let apolloProvider;

  const createQueryResponse = (lifecycles = mockLifecycles) => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        lifecycles: {
          nodes: lifecycles,
        },
      },
    },
  });

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLifecycleContainers = () => wrapper.findAll('[data-testid="lifecycle-container"]');
  const findStatusBadges = () => wrapper.findAllComponents(WorkItemStatusBadge);
  const findEditButtons = () => wrapper.findAllByTestId('edit-statuses');
  const findHelpPageLink = () => wrapper.findByTestId('settings-help-page-link');
  const findMoreLifecycleInformation = () => wrapper.findByTestId('more-lifecycle-information');
  const findCreateLifecycleButton = () => wrapper.findByTestId('create-lifecycle');
  const findLifecyclesDetails = () => wrapper.findAllComponents(LifecycleDetail);
  const findCreateLifecycleModal = () => wrapper.findComponent(CreateLifecycleModal);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusModal = () => wrapper.findComponent(StatusModal);
  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);

  const createComponent = ({
    props = {},
    workItemStatusMvc2Enabled = true,
    queryHandler = jest.fn().mockResolvedValue(createQueryResponse()),
  } = {}) => {
    apolloProvider = createMockApollo([[namespaceStatusesQuery, queryHandler]]);

    wrapper = shallowMountExtended(NamespaceLifecycles, {
      propsData: {
        fullPath: 'gitlab-org',
        ...props,
      },
      apolloProvider,
      provide: {
        glFeatures: {
          workItemStatusMvc2: workItemStatusMvc2Enabled,
        },
      },
      stubs: {
        SettingsBlock,
      },
    });
  };

  describe('Default', () => {
    it('renders a settings block', () => {
      createComponent();

      expect(findSettingsBlock().props()).toMatchObject({
        id: 'js-custom-status-settings',
        title: 'Statuses',
      });
    });

    it('renders the help page link', async () => {
      createComponent();
      await waitForPromises();
      expect(findHelpPageLink().exists()).toBe(true);
      expect(findHelpPageLink().props('href')).toBe('user/work_items/status');
    });
  });

  describe('query success', () => {
    beforeEach(() => {
      createComponent({ workItemStatusMvc2Enabled: false });
      return waitForPromises();
    });

    it('renders correct number of lifecycle containers', () => {
      expect(findLifecycleContainers()).toHaveLength(2);
    });

    it('renders work item types with icons and names', () => {
      const firstLifecycle = findLifecycleContainers().at(0);
      const icons = firstLifecycle.findAllComponents(GlIcon);

      expect(icons.at(0).props('name')).toBe('issue-type-issue');
      expect(firstLifecycle.text()).toContain('Issue');
      expect(icons.at(1).props('name')).toBe('issue-type-task');
      expect(firstLifecycle.text()).toContain('Task');
    });

    it('renders status badges with correct props', () => {
      const statusBadges = findStatusBadges();

      expect(statusBadges).toHaveLength(5); // 3 from first lifecycle + 2 from second

      expect(statusBadges.at(0).props()).toMatchObject({
        item: {
          name: 'Open',
          iconName: 'issue-open',
          color: 'green',
        },
      });

      expect(statusBadges.at(1).props()).toMatchObject({
        item: {
          name: 'In Progress',
          iconName: 'progress',
          color: 'blue',
        },
      });
    });

    it('renders edit button for each lifecycle', () => {
      const editButtons = findEditButtons();

      expect(editButtons).toHaveLength(2);
      expect(editButtons.at(0).text()).toBe('Edit statuses');
      expect(editButtons.at(0).props('size')).toBe('small');
    });
  });

  describe('when query fails', () => {
    const error = new Error('GraphQL error');

    beforeEach(() => {
      createComponent({
        queryHandler: jest.fn().mockRejectedValue(error),
        workItemStatusMvc2Enabled: false,
      });
      return waitForPromises();
    });

    it('displays error alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().props('dismissible')).toBe(true);
      expect(findAlert().text()).toContain('Failed to load lifecycles.');
      expect(findAlert().find('details').text()).toContain(error.message);
    });

    it('calls Sentry.captureException', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('hides alert when dismissed', async () => {
      expect(findAlert().exists()).toBe(true);

      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when `workItemStatusMvc2Enabled` FF is true', () => {
    beforeEach(() => {
      createComponent({
        workItemStatusMvc2Enabled: true,
      });
      return waitForPromises();
    });

    it('shows lifecycle information', () => {
      expect(findMoreLifecycleInformation().exists()).toBe(true);
    });

    it('shows create lifecycle button and modal', async () => {
      expect(findCreateLifecycleButton().exists()).toBe(true);
      expect(findCreateLifecycleModal().props('visible')).toBe(false);

      await findCreateLifecycleButton().vm.$emit('click');

      expect(findCreateLifecycleModal().props('visible')).toBe(true);
    });

    it('renders lifecycle detail components', () => {
      expect(findLifecyclesDetails()).toHaveLength(2);
    });
  });

  describe('initial loading state', () => {
    it('shows loading icon while loading initial lifecycles', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLoadingIcon().props('size')).toBe('lg');
    });

    it('hides loading icon after initial lifecycles are loaded', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('hides loading icon on subsequent refetches', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);

      // Trigger a refetch by emitting the deleted event from LifecycleDetail
      const firstLifecycleDetail = findLifecyclesDetails().at(0);
      await firstLifecycleDetail.vm.$emit('deleted');

      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('Edit Button and Modal Functionality', () => {
    beforeEach(() => {
      createComponent({ workItemStatusMvc2Enabled: true });
      return waitForPromises();
    });

    describe('Edit Button Interactions', () => {
      it('opens status modal when edit button is clicked', async () => {
        const lifecycleDetails = findLifecyclesDetails();
        const firstLifecycleDetail = lifecycleDetails.at(0);
        const editButton = firstLifecycleDetail.findComponent(GlButton);

        // Modal should not be visible initially
        expect(findStatusModal().exists()).toBe(false);

        // Click the edit button
        await editButton.vm.$emit('click');
        await nextTick();

        // Modal should now exist and be visible
        const statusModal = findStatusModal();
        expect(statusModal.exists()).toBe(true);
        expect(statusModal.props('visible')).toBe(true);
      });

      it('renders edit button with correct text in lifecycle detail footer', () => {
        const lifecycleDetails = findLifecyclesDetails();

        lifecycleDetails.wrappers.forEach((lifecycleDetail) => {
          const editButton = lifecycleDetail.findComponent(GlButton);
          expect(editButton.exists()).toBe(true);
          expect(editButton.text()).toBe('Edit statuses');
        });
      });
    });

    describe('Status Modal Props and Visibility', () => {
      it('passes allNamespaceStatuses as statuses prop', async () => {
        const lifecycleDetails = findLifecyclesDetails();
        const editButton = lifecycleDetails.at(0).findComponent(GlButton);

        await editButton.vm.$emit('click');
        await nextTick();

        const statusModal = findStatusModal();
        const allStatuses = statusModal.props('statuses');

        // Should contain all unique statuses from all lifecycles
        expect(allStatuses).toHaveLength(5); // 3 from first lifecycle + 2 from second (all unique)

        // Verify it contains expected status names
        const statusNames = allStatuses.map((status) => status.name);
        expect(statusNames).toContain('Open');
        expect(statusNames).toContain('In Progress');
        expect(statusNames).toContain('Closed');
        expect(statusNames).toContain('New');
        expect(statusNames).toContain('Resolved');
      });

      it('passes correct fullPath prop to modal', async () => {
        const lifecycleDetails = findLifecyclesDetails();
        const editButton = lifecycleDetails.at(0).findComponent(GlButton);

        await editButton.vm.$emit('click');
        await nextTick();

        expect(findStatusModal().props('fullPath')).toBe('gitlab-org');
      });

      it('does not render modal when no lifecycle is selected', () => {
        // Initially, no lifecycle should be selected
        expect(findStatusModal().exists()).toBe(false);
      });
    });

    describe('Modal Event Handling', () => {
      it('closes modal when close event is emitted', async () => {
        const lifecycleDetails = findLifecyclesDetails();
        const editButton = lifecycleDetails.at(0).findComponent(GlButton);

        // Open modal
        await editButton.vm.$emit('click');
        await nextTick();

        expect(findStatusModal().exists()).toBe(true);
        expect(findStatusModal().props('visible')).toBe(true);

        // Close modal
        await findStatusModal().vm.$emit('close');
        await nextTick();

        // Modal should no longer exist
        expect(findStatusModal().exists()).toBe(false);
      });

      it('refetches lifecycles when lifecycle-updated event is emitted', async () => {
        const mockQueryHandler = jest.fn().mockResolvedValue(createQueryResponse());
        createComponent({
          queryHandler: mockQueryHandler,
        });
        await waitForPromises();

        const lifecycleDetails = findLifecyclesDetails();
        const editButton = lifecycleDetails.at(0).findComponent(GlButton);

        // Open modal
        await editButton.vm.$emit('click');
        await nextTick();

        // Emit lifecycle-updated event
        await findStatusModal().vm.$emit('lifecycle-updated');
        await nextTick();

        // Should trigger a refetch
        expect(mockQueryHandler).toHaveBeenCalled();
      });
    });

    describe('Lifecycle Detail Integration', () => {
      it('handles lifecycle deleted event', async () => {
        const mockQueryHandler = jest.fn().mockResolvedValue(createQueryResponse());
        createComponent({
          queryHandler: mockQueryHandler,
        });
        await waitForPromises();

        const lifecycleDetails = findLifecyclesDetails();
        const firstLifecycleDetail = lifecycleDetails.at(0);

        // Emit deleted event
        await firstLifecycleDetail.vm.$emit('deleted');
        await nextTick();

        // Should trigger a refetch
        expect(mockQueryHandler).toHaveBeenCalled();
      });
    });
  });
});
