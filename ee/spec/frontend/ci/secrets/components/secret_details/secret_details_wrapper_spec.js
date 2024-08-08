import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlBadge, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EDIT_ROUTE_NAME, DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';
import getSecretDetailsQuery from 'ee/ci/secrets/graphql/queries/client/get_secret_details.query.graphql';
import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import { mockProjectSecretQueryResponse } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretDetailsWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockSecretQuery;

  const mockRouter = {
    push: jest.fn(),
  };

  const defaultProps = {
    fullPath: 'path/to/project',
    routeName: 'details',
    secretId: 1,
  };

  const createComponent = async ({
    props = {},
    stubs = {},
    isLoading = false,
    mountFn = shallowMountExtended,
    routeName = DETAILS_ROUTE_NAME,
  } = {}) => {
    mockApollo = createMockApollo([[getSecretDetailsQuery, mockSecretQuery]]);

    wrapper = mountFn(SecretDetailsWrapper, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        RouterView: true,
        ...stubs,
      },
      mocks: {
        $router: mockRouter,
        $route: { name: routeName },
      },
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCreatedAt = () => wrapper.findByTestId('secret-created-at');
  const findDeleteButton = () => wrapper.findByTestId('secret-delete-button');
  const findEditButton = () => wrapper.findByTestId('secret-edit-button');
  const findKey = () => wrapper.find('h1');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRevokeButton = () => wrapper.findByTestId('secret-revoke-button');
  const findStatus = () => wrapper.findComponent(GlBadge);

  beforeEach(() => {
    mockSecretQuery = jest.fn();
  });

  describe('when query is loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when query fails', () => {
    beforeEach(async () => {
      mockSecretQuery.mockRejectedValue();
      await createComponent();
    });

    it('renders alert message', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to load secret. Please try again later.',
      });
    });
  });

  describe('when no secret is found', () => {
    beforeEach(async () => {
      mockSecretQuery.mockResolvedValue({ data: { project: { secret: null } } });
      await createComponent();
    });

    it('renders alert message', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findAlert().text()).toBe('Failed to load secret. Please try again later.');
    });
  });

  describe('when query succeeds', () => {
    beforeEach(async () => {
      mockSecretQuery.mockResolvedValue(mockProjectSecretQueryResponse());
      await createComponent();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders action buttons', () => {
      expect(findDeleteButton().exists()).toBe(true);
      expect(findEditButton().exists()).toBe(true);
      expect(findRevokeButton().exists()).toBe(true);
    });

    it('renders secret details', () => {
      expect(findStatus().text()).toBe('Enabled');
      expect(findKey().text()).toBe('APP_PWD');
      expect(findCreatedAt().text()).toBe('Created on Jan 22, 2024');
    });

    it('shows a link to the edit secret page', async () => {
      createComponent();
      await waitForPromises();

      findEditButton().vm.$emit('click');
      expect(mockRouter.push).toHaveBeenCalledWith({
        name: EDIT_ROUTE_NAME,
        params: { id: defaultProps.secretId },
      });
    });
  });
});
