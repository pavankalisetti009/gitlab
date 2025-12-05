import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
  SECRET_MANAGER_STATUS_DEPROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import SecretManagerSettings, {
  POLL_INTERVAL,
} from 'ee/pages/projects/shared/permissions/secrets_manager/secrets_manager_settings.vue';
import {
  initializeSecretManagerSettingsResponse,
  initializeGroupSecretManagerSettingsResponse,
  secretManagerSettingsResponse,
  groupSecretManagerSettingsResponse,
} from './mock_data';

Vue.use(VueApollo);
const showToast = jest.fn();

describe('SecretManagerSettings', () => {
  let wrapper;
  let mockEnableSecretManager;
  let mockEnableGroupSecretManager;
  let mockSecretManagerStatus;

  const activeResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_ACTIVE);
  const provisioningResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_PROVISIONING);
  const deprovisioningResponse = secretManagerSettingsResponse(
    SECRET_MANAGER_STATUS_DEPROVISIONING,
  );
  // secrets manager has not been provisioned yet, so status would be NULL when it's inactive
  const inactiveResponse = secretManagerSettingsResponse(null);
  const errorResponse = secretManagerSettingsResponse(null, [{ message: 'Some error occurred' }]);

  const groupActiveResponse = groupSecretManagerSettingsResponse(SECRET_MANAGER_STATUS_ACTIVE);
  const groupProvisioningResponse = groupSecretManagerSettingsResponse(
    SECRET_MANAGER_STATUS_PROVISIONING,
  );
  const groupInactiveResponse = groupSecretManagerSettingsResponse(null);

  const fullPath = 'gitlab-org/gitlab';

  const createComponent = async ({ context = 'project', ...props } = {}) => {
    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [enableSecretManagerMutation, mockEnableSecretManager],
      [getGroupSecretManagerStatusQuery, mockSecretManagerStatus],
      [enableGroupSecretManagerMutation, mockEnableGroupSecretManager],
    ];

    const defaultProps =
      context === 'project'
        ? { canManageSecretsManager: true, fullPath, context: 'project', projectId: 1 }
        : { canManageSecretsManager: true, fullPath, context: 'group' };

    wrapper = shallowMountExtended(SecretManagerSettings, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $toast: { show: showToast },
      },
    });

    await waitForPromises();
    await nextTick();
  };

  const findError = () => wrapper.findByTestId('secret-manager-error');
  const findLearnMoreLink = () => wrapper.findComponent(GlLink);
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findPermissionsSettings = () => wrapper.findComponent(PermissionsSettings);

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (queryResponse) => {
    mockSecretManagerStatus.mockResolvedValue(queryResponse);
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockEnableSecretManager = jest.fn();
    mockEnableGroupSecretManager = jest.fn();
    mockSecretManagerStatus = jest.fn();
  });

  describe('template', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
      await createComponent({ canManageSecretsManager: false });
    });

    it('disables toggle when user does not have permission', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });

    it('renders learn more link', () => {
      expect(findLearnMoreLink().attributes('href')).toBe(
        '/help/ci/secrets/secrets_manager/_index',
      );
    });
  });

  describe('when query is loading', () => {
    it('disables toggle and shows loading state', () => {
      createComponent();

      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('isLoading')).toBe(true);
    });
  });

  describe('when query receives an error', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(errorResponse);
      await createComponent();
    });

    it('disables toggle', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });

    it('shows error message', () => {
      expect(findError().text()).toBe('Some error occurred');
    });

    it('does not render permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe('when query receives DEPROVISIONING status', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(deprovisioningResponse);
      await createComponent();
    });

    it('disables toggle and shows loading state', () => {
      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('does not render permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe.each([
    {
      context: 'project',
      contextActiveResponse: activeResponse,
      contextProvisioningResponse: provisioningResponse,
      contextInactiveResponse: inactiveResponse,
      mockMutation: () => mockEnableSecretManager,
      mutationResponse: initializeSecretManagerSettingsResponse,
      pathKey: 'fullPath',
      toastMessage: 'Secrets manager has been provisioned for this project.',
    },
    {
      context: 'group',
      contextActiveResponse: groupActiveResponse,
      contextProvisioningResponse: groupProvisioningResponse,
      contextInactiveResponse: groupInactiveResponse,
      mockMutation: () => mockEnableGroupSecretManager,
      mutationResponse: initializeGroupSecretManagerSettingsResponse,
      pathKey: 'fullPath',
      toastMessage: 'Secrets manager has been provisioned for this group.',
    },
  ])(
    '$context context',
    ({
      context,
      contextActiveResponse,
      contextProvisioningResponse,
      contextInactiveResponse,
      mockMutation,
      mutationResponse,
      pathKey,
      toastMessage,
    }) => {
      const toggleSetting = async (errors = []) => {
        const response = mutationResponse(errors);
        mockMutation().mockResolvedValue(response);

        findToggle().vm.$emit('change', true);
        await waitForPromises();
      };

      describe('when query receives ACTIVE status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextActiveResponse);
          await createComponent({ context });
        });

        it('shows active state', () => {
          expect(findToggle().props('value')).toBe(true);
        });

        it('renders permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(true);
        });
      });

      describe('when query receives INACTIVE status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent();
        });

        it('shows inactive state', () => {
          expect(findToggle().props('value')).toBe(false);
        });

        it('renders permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when query receives PROVISIONING status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextProvisioningResponse);
          await createComponent({ context });
        });

        it('disables toggle and shows loading state', () => {
          expect(findToggle().props('disabled')).toBe(true);
          expect(findToggle().props('isLoading')).toBe(true);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when query receives NULL status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent({ context });
        });

        it('shows inactive state', () => {
          expect(findToggle().props('disabled')).toBe(false);
          expect(findToggle().props('value')).toBe(false);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when enabling the secrets manager', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent({ context });
        });

        it('sends mutation request', async () => {
          await toggleSetting();

          expect(mockMutation()).toHaveBeenCalledWith({
            [pathKey]: fullPath,
          });
        });

        it('shows error message on failure and disables toggle', async () => {
          await toggleSetting(['Error encountered']);

          expect(findError().exists()).toBe(true);
          expect(findToggle().props('disabled')).toBe(true);
        });

        it('starts polling for a new status while status is PROVISIONING', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleSetting();
          await pollNextStatus(contextProvisioningResponse);
          await pollNextStatus(contextProvisioningResponse);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(3);
        });

        it('stops polling for status when new status is ACTIVE', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleSetting();
          await pollNextStatus(contextActiveResponse);
          await pollNextStatus(contextActiveResponse);

          expect(findToggle().props('value')).toBe(true);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
        });

        it('shows toast message on success', async () => {
          await toggleSetting();
          await pollNextStatus(contextActiveResponse);

          expect(showToast).toHaveBeenCalledWith(toastMessage);
        });
      });
    },
  );
});
