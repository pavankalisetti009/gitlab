import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import Vue, { nextTick } from 'vue';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createRouter from 'ee/ci/secrets/router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretsApp from 'ee/ci/secrets/components/secrets_app.vue';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import {
  POLL_INTERVAL,
  ENTITY_GROUP,
  ENTITY_PROJECT,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import { secretManagerStatusResponse } from '../mock_data';

jest.mock('~/alert');

describe('SecretsApp', () => {
  let wrapper;
  let apolloProvider;
  let mockSecretManagerStatus;

  Vue.use(VueRouter);
  Vue.use(VueApollo);
  const mockToastShow = jest.fn();

  const findRouterView = () => wrapper.findComponent({ ref: 'router-view' });

  const createComponent = async ({ stubs, router, provide, isLoading = false } = {}) => {
    const handlers = [[getSecretManagerStatusQuery, mockSecretManagerStatus]];

    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsApp, {
      router,
      provide: {
        fullPath: '/path/to/project',
        contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_PROJECT],
        ...provide,
      },
      stubs,
      apolloProvider,
      mocks: {
        $toast: { show: mockToastShow },
      },
    });

    if (!isLoading) {
      await waitForPromises();
      await nextTick();
    }
  };

  const findLoadingIcon = () => wrapper.findByTestId('secrets-manager-loading-status');
  const findProvisioningText = () => wrapper.findByTestId('secrets-manager-provisioning-text');

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (status) => {
    mockSecretManagerStatus.mockResolvedValue(secretManagerStatusResponse(status));
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockSecretManagerStatus = jest.fn();

    mockSecretManagerStatus.mockResolvedValue(
      secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE),
    );
  });

  describe('when secrets manager status is being fetched', () => {
    beforeEach(() => {
      createComponent({ stubs: { RouterView: true }, isLoading: true });
    });

    it('renders the loading state', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the provisioning state or the router view', () => {
      expect(findProvisioningText().exists()).toBe(false);
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('when secrets manager is being provisioned', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(
        secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING),
      );
      await createComponent({ stubs: { RouterView: true } });
    });

    it('renders the provisioning state', () => {
      expect(findProvisioningText().exists()).toBe(true);
    });

    it('does not render the loading state or router view', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findRouterView().exists()).toBe(false);
    });

    it('polls for updated status while provisioning', async () => {
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

      await pollNextStatus(SECRET_MANAGER_STATUS_PROVISIONING);

      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
    });

    it('renders router view when provisioned', async () => {
      expect(findRouterView().exists()).toBe(false);
      expect(findProvisioningText().exists()).toBe(true);

      await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);

      expect(findProvisioningText().exists()).toBe(false);
      expect(findRouterView().exists()).toBe(true);
    });

    it('stops polling when provisioned', async () => {
      await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);

      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);

      await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);
      await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
    });
  });

  describe('when secrets manager has been provisioned', () => {
    beforeEach(async () => {
      await createComponent({ stubs: { RouterView: true } });
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
    });

    it('stops polling for status', async () => {
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

      await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);

      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
    });
  });

  describe('when there is an error with fetching the secrets manager status', () => {
    const error = new Error('GraphQL error: API error');

    beforeEach(async () => {
      mockSecretManagerStatus.mockRejectedValue(error);
      await createComponent({ stubs: { RouterView: true } });
    });

    it('renders an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'API error',
        captureError: true,
        error,
      });
    });

    it('stops polling', async () => {
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

      advanceToNextFetch(POLL_INTERVAL);

      await waitForPromises();
      await nextTick();

      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
    });

    it('does not render the loading state or router view', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('toast message', () => {
    beforeEach(async () => {
      await createComponent({
        router: createRouter('/-/secrets', {
          contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_PROJECT],
          fullPath: '/path/to/project',
        }),
      });
    });

    it('renders toast message when show-secrets-toast is emitted', async () => {
      findRouterView().vm.$emit('show-secrets-toast', 'This is a toast message.');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith('This is a toast message.');
    });
  });

  describe('group context', () => {
    beforeEach(async () => {
      await createComponent({
        stubs: { RouterView: true },
        provide: { contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_GROUP] },
      });
    });

    it('skips secrets manager status query', () => {
      expect(mockSecretManagerStatus).not.toHaveBeenCalled();
    });

    it('does not show loading icon or provisioning state', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findProvisioningText().exists()).toBe(false);
    });
  });
});
