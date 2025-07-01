import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CentralizedSecurityPolicyManagement from 'ee/admin/application_settings/security_and_compliance/components/centralized_security_policy_management.vue';
import Api from 'ee/api';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';

jest.mock('ee/api');

const mockGroupsResponse = {
  data: {
    groups: {
      nodes: [
        {
          id: 'gid://gitlab/Group/1',
          name: 'Group 1',
          fullName: 'Group 1',
          fullPath: 'group-1',
          avatarUrl: 'avatar1.png',
        },
        {
          id: 'gid://gitlab/Group/2',
          name: 'Group 2',
          fullName: 'Group 2',
          fullPath: 'group-2',
          avatarUrl: 'avatar2.png',
        },
      ],
      pageInfo: {
        __typename: 'PageInfo',
        hasNextPage: false,
        hasPreviousPage: false,
        endCursor: null,
        startCursor: null,
      },
    },
  },
};

describe('CentralizedSecurityPolicyManagement', () => {
  let wrapper;
  let requestHandler;

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;
    return createMockApollo([[getGroups, requestHandler]]);
  };

  const createComponent = ({
    props = {},
    handler = jest.fn().mockResolvedValue(mockGroupsResponse),
  } = {}) => {
    wrapper = shallowMountExtended(CentralizedSecurityPolicyManagement, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        formId: 'test-form',
        ...props,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSaveButton = () => wrapper.findByTestId('save-button');
  const findUnassignButton = () => wrapper.findByTestId('unassign-button');

  beforeEach(() => {
    // Mock DOM element for form submission
    document.getElementById = jest.fn().mockReturnValue({
      submit: jest.fn(),
    });
  });

  afterEach(() => {
    Api.updatePolicySettings.mockReset();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the collapsible listbox with correct props', () => {
      const listbox = findListbox();

      expect(listbox.exists()).toBe(true);
      expect(listbox.props('searchable')).toBe(true);
      expect(listbox.props('isCheckCentered')).toBe(true);
      expect(listbox.props('toggleText')).toBe('Select a group');
    });

    it('renders save button', () => {
      expect(findSaveButton().exists()).toBe(true);
    });
  });

  describe('group selection', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('updates toggle text when a group is selected', async () => {
      findListbox().vm.$emit('select', 1);
      await nextTick();

      expect(findListbox().props('toggleText')).toBe('Group 1');
    });

    it('updates selected group when user selects from listbox', async () => {
      findListbox().vm.$emit('select', 1);
      await nextTick();
      expect(findListbox().props('selected')).toBe(1);
    });
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      jest.useFakeTimers({ legacyFakeTimers: false });
      createComponent();
      await waitForPromises();
    });

    afterEach(() => {
      jest.useFakeTimers({ legacyFakeTimers: true });
    });

    it('handles search input with debouncing', async () => {
      const searchTerm = 'test search';
      findListbox().vm.$emit('search', searchTerm);
      expect(requestHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({ search: searchTerm }),
      );
    });
  });

  describe('infinite scroll', () => {
    const mockResponseWithNextPage = {
      data: {
        groups: {
          nodes: mockGroupsResponse.data.groups.nodes,
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: 'cursor2',
          },
        },
      },
    };

    it('shows infinite scroll when there are more pages', async () => {
      createComponent({ handler: jest.fn().mockResolvedValue(mockResponseWithNextPage) });
      await waitForPromises();
      expect(findListbox().props('infiniteScroll')).toBe(true);
    });

    it('triggers load more when bottom is reached', async () => {
      const mockSecondResponse = {
        data: {
          groups: {
            nodes: [{ ...mockGroupsResponse.data.groups.nodes[0], id: 'gid://gitlab/Group/3' }],
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage: false,
              hasPreviousPage: true,
              startCursor: 'cursor2',
              endCursor: null,
            },
          },
        },
      };

      createComponent({
        handler: jest
          .fn()
          .mockResolvedValueOnce(mockResponseWithNextPage)
          .mockResolvedValueOnce(mockSecondResponse),
      });
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(1);
      findListbox().vm.$emit('bottom-reached');
      expect(requestHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('loading states', () => {
    it('shows loading state during Apollo query', () => {
      createComponent();

      expect(findListbox().props('loading')).toBe(true);
    });

    it('disables save button during loading', () => {
      createComponent();

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('save functionality', () => {
    beforeEach(() => {
      Api.updatePolicySettings.mockResolvedValue({});
    });

    it('calls API and submits form when save button is clicked with selected group', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('select', 1);
      await nextTick();

      findSaveButton().vm.$emit('click');
      await nextTick();

      expect(Api.updatePolicySettings).toHaveBeenCalledWith({
        csp_namespace_id: 1,
      });
    });

    it('shows loading state during save operation', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('select', 1);
      await nextTick();

      // Mock a pending API call
      Api.updatePolicySettings.mockImplementation(() => new Promise(() => {}));

      findSaveButton().vm.$emit('click');
      await nextTick();

      expect(findListbox().props('loading')).toBe(true);
      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('unassign functionality', () => {
    beforeEach(() => {
      Api.updatePolicySettings.mockResolvedValue({});
    });

    it('calls API with null when unassign button is clicked', async () => {
      createComponent({ props: { selectedGroupId: 1 } });
      await waitForPromises();

      findUnassignButton().vm.$emit('click');
      await nextTick();

      expect(Api.updatePolicySettings).toHaveBeenCalledWith({
        csp_namespace_id: null,
      });
    });
  });

  describe('lifecycle hooks', () => {
    it('cancels debounced search when component is destroyed', async () => {
      createComponent();
      await waitForPromises();

      const cancelSpy = jest.spyOn(wrapper.vm.handleSearch, 'cancel');

      // Stop Apollo queries before destroying to prevent console errors
      await wrapper.vm.$apollo.queries.groups.stop();
      wrapper.destroy();

      expect(cancelSpy).toHaveBeenCalled();
    });
  });
});
