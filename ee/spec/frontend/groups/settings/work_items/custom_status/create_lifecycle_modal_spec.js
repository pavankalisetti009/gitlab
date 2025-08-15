import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlForm, GlSearchBoxByType, GlFormRadioGroup, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import CreateLifecycle from 'ee/groups/settings/work_items/custom_status/create_lifecycle_modal.vue';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import namespaceStatusesQuery from 'ee/groups/settings/work_items/custom_status/namespace_lifecycles.query.graphql';
import namespaceDefaultLifecycleQuery from 'ee/groups/settings/work_items/custom_status/namespace_default_lifecycle.query.graphql';
import { mockLifecycles, mockDefaultLifecycle } from '../mock_data';

Vue.use(VueApollo);

// Mock Sentry
jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

const mockNamespaceStatusesResponse = {
  data: {
    namespace: {
      __typename: 'Namespace',
      id: 'gid://gitlab/Group/1',
      lifecycles: {
        nodes: mockLifecycles,
      },
    },
  },
};

const mockNamespaceDefaultLifecycleResponse = {
  data: {
    namespaceDefaultLifecycle: {
      __typename: 'LocalNamespace',
      id: 'gid://gitlab/Namespace/default',
      lifecycle: mockDefaultLifecycle,
    },
  },
};

describe('CreateLifecycle', () => {
  let wrapper;
  let mockApollo;

  const namespacesQueryHandler = jest.fn().mockResolvedValue(mockNamespaceStatusesResponse);
  const defaultLifecycleQueryHandler = jest
    .fn()
    .mockResolvedValue(mockNamespaceDefaultLifecycleResponse);

  const createComponent = ({
    mountFn = shallowMountExtended,
    props = {},
    namespacesHandler = namespacesQueryHandler,
  } = {}) => {
    mockApollo = createMockApollo([[namespaceStatusesQuery, namespacesHandler]]);

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: namespaceDefaultLifecycleQuery,
      variables: {
        fullPath: 'test/project',
      },
      data: {
        ...mockNamespaceDefaultLifecycleResponse.data,
      },
    });

    wrapper = mountFn(CreateLifecycle, {
      apolloProvider: mockApollo,
      propsData: {
        visible: true,
        fullPath: 'test/project',
        ...props,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findByTestId('new-lifecycle-name-field');
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findLifecycleDetails = () => wrapper.findAllComponents(LifecycleDetail);
  const findDefaultLifecycleDetail = () => wrapper.findAllComponents(LifecycleDetail).at(0);

  describe('when component is mounted', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props()).toMatchObject({
        title: 'Create lifecycle',
        modalId: 'create-lifecycle-modal',
      });
    });

    it('renders the form elements', () => {
      expect(findForm().exists()).toBe(true);
      expect(findNameInput().exists()).toBe(true);
      expect(findRadioGroup().exists()).toBe(true);
      expect(findSearchBox().exists()).toBe(true);
    });

    it('renders the lifecycle name input field', () => {
      expect(findNameInput().exists()).toBe(true);
      expect(findNameInput().attributes('id')).toBe('new-lifecycle-name');
    });
  });

  describe('loading states', () => {
    it('shows loading icon while queries are loading', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findRadioGroup().exists()).toBe(false);
    });

    it('hides loading icon when queries are loaded', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findRadioGroup().exists()).toBe(true);
    });
  });

  describe('Apollo queries', () => {
    it('calls namespace lifecycles query with correct variables', async () => {
      createComponent();
      await waitForPromises();

      expect(namespacesQueryHandler).toHaveBeenCalledWith({
        fullPath: 'test/project',
      });
    });

    it('skips queries when not visible', () => {
      createComponent({ props: { visible: false } });

      // Since Apollo queries have skip condition, handlers won't be called
      expect(namespacesQueryHandler).not.toHaveBeenCalled();
      expect(defaultLifecycleQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('lifecycle selection', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders default lifecycle option', () => {
      const defaultDetail = findDefaultLifecycleDetail();

      expect(defaultDetail.exists()).toBe(true);
      expect(defaultDetail.props()).toMatchObject({
        lifecycle: mockDefaultLifecycle,
        isDefaultLifecycle: true,
        showRadioSelection: true,
      });
    });

    it('renders all lifecycle options', () => {
      const lifecycleDetails = findLifecycleDetails();

      // +1 for default lifecycle
      expect(lifecycleDetails).toHaveLength(mockLifecycles.length + 1);
    });

    it('applies selected border style to selected lifecycle', () => {
      const defaultDetail = findDefaultLifecycleDetail();

      expect(defaultDetail.classes()).toContain('gl-border-blue-500');
    });
  });
});
