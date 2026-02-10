import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlCollapsibleListbox,
  GlFormInput,
  GlDatepicker,
  GlFormCheckbox,
  GlModal,
} from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import Api from '~/api';
import * as RestApi from '~/rest_api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';
import createSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/create_secrets_permission.mutation.graphql';
import createGroupSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/create_group_secrets_permission.mutation.graphql';
import {
  MOCK_USERS_API,
  mockCreatePermissionResponse,
  mockCreatePermissionErrorResponse,
  mockCreateGroupPermissionResponse,
  mockCreateGroupPermissionErrorResponse,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/rest_api');

const mockToastShow = jest.fn();
Vue.use(VueApollo);

describe('SecretsManagerPermissionsModal', () => {
  let wrapper;
  let mockApollo;
  let mockCreatePermission;

  const contextConfigs = [
    {
      context: 'project',
      fullPath: '/path/to/project',
      mutation: createSecretsPermissionMutation,
      mockSuccessResponse: mockCreatePermissionResponse,
      mockErrorResponse: mockCreatePermissionErrorResponse,
      mockApiCall: () => jest.spyOn(Api, 'projectUsers'),
    },
    {
      context: 'group',
      fullPath: '/path/to/group',
      mutation: createGroupSecretsPermissionMutation,
      mockSuccessResponse: mockCreateGroupPermissionResponse,
      mockErrorResponse: mockCreateGroupPermissionErrorResponse,
      mockApiCall: () => jest.spyOn(RestApi, 'getGroupMembers'),
    },
  ];

  const createComponent = ({ permissionCategory = null, context = 'project' } = {}) => {
    const config = contextConfigs.find((c) => c.context === context);

    mockApollo = createMockApollo([[config.mutation, mockCreatePermission]]);

    wrapper = shallowMountExtended(PermissionsModal, {
      apolloProvider: mockApollo,
      propsData: {
        permissionCategory,
        fullPath: config.fullPath,
        projectId: 123,
        context,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
  };

  const findDatepicker = () => wrapper.findComponent(GlDatepicker);
  const findCheckbox = (index) => wrapper.findAllComponents(GlFormCheckbox).at(index);
  const findModal = () => wrapper.findComponent(GlModal);
  const findPrincipalField = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGroupPathInput = () => wrapper.findComponent(GlFormInput);

  const inputRequiredFields = async (selectedItem = 'MAINTAINER', isGroup = false) => {
    // expiredAt is optional
    findCheckbox(0).vm.$emit('input', true);
    findCheckbox(1).vm.$emit('input', true);

    if (isGroup) {
      findGroupPathInput().vm.$emit('input', 'my-org/sub-group');
    } else {
      findPrincipalField().vm.$emit('select', selectedItem);
    }

    await nextTick();
  };

  const submitPermission = async ({
    includeOptionalFields = false,
    selectedItem = 'MAINTAINER',
    isGroup = false,
  } = {}) => {
    if (includeOptionalFields) {
      findDatepicker().vm.$emit('input', new Date('2055-08-12'));
    }

    await inputRequiredFields(selectedItem, isGroup);
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
  };

  const waitForDebounce = () => {
    jest.runOnlyPendingTimers();
    return waitForPromises();
  };

  beforeEach(() => {
    jest.spyOn(Api, 'projectUsers').mockResolvedValue(MOCK_USERS_API);
    jest.spyOn(RestApi, 'getGroupMembers').mockResolvedValue({ data: MOCK_USERS_API });
    mockCreatePermission = jest.fn().mockResolvedValue(mockCreatePermissionResponse);
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('hides modal when permission category is not provided', () => {
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('modal behavior', () => {
    beforeEach(() => {
      createComponent({ permissionCategory: 'ROLE' });
    });

    it('disables all checkboxes except the first', () => {
      expect(findCheckbox(0).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(1).attributes('disabled')).toBeDefined();
      expect(findCheckbox(2).attributes('disabled')).toBeDefined();
    });

    it('enables all checkboxes when the first checkbox is selected', async () => {
      findCheckbox(0).vm.$emit('input', true);
      await nextTick();

      expect(findCheckbox(1).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(2).attributes('disabled')).toBeUndefined();
    });

    it.each`
      modalEvent     | emittedEvent
      ${'canceled'}  | ${'hide'}
      ${'hidden'}    | ${'hide'}
      ${'secondary'} | ${'hide'}
    `(
      'emits the $emittedEvent event when $modalEvent event is triggered',
      ({ modalEvent, emittedEvent }) => {
        expect(wrapper.emitted(emittedEvent)).toBeUndefined();

        findModal().vm.$emit(modalEvent);

        expect(wrapper.emitted(emittedEvent)).toHaveLength(1);
      },
    );
  });

  const USER_ITEMS = ['Administrator', 'John Doe'];
  const ROLE_ITEMS = ['Reporter', 'Developer', 'Maintainer'];

  describe.each([
    {
      contextName: 'project',
      contextConfig: contextConfigs[0],
    },
    {
      contextName: 'group',
      contextConfig: contextConfigs[1],
    },
  ])('$contextName context', ({ contextName, contextConfig }) => {
    describe.each`
      category  | title         | fieldItems    | selectedItem    | principalId
      ${'USER'} | ${'Add user'} | ${USER_ITEMS} | ${'john.doe'}   | ${2}
      ${'ROLE'} | ${'Add role'} | ${ROLE_ITEMS} | ${'MAINTAINER'} | ${40}
    `(
      '$category permissions form',
      ({ category, title, fieldItems, selectedItem, principalId }) => {
        beforeEach(async () => {
          mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
          createComponent({ permissionCategory: category, context: contextName });
          findPrincipalField().vm.$emit('shown');
          await waitForPromises();
        });

        it('renders modal', () => {
          expect(findModal().props('visible')).toBe(true);
        });

        it('renders template correctly', () => {
          expect(findModal().props('title')).toBe(title);
          expect(findDatepicker().exists()).toBe(true);
          expect(findCheckbox(0).text()).toContain('Read');
          expect(findCheckbox(1).text()).toContain('Write');
          expect(findCheckbox(2).text()).toContain('Delete');
        });

        it('sets expiration date in the future', () => {
          const today = new Date();
          const expirationMinDate = findDatepicker().props('minDate').getTime();
          expect(expirationMinDate).toBeGreaterThan(today.getTime());
        });

        it('fills listbox with correct items', () => {
          const actualFieldItems = findPrincipalField()
            .props('items')
            .map((item) => item.text);

          expect(actualFieldItems).toEqual(fieldItems);
        });

        it('calls the create mutation with the correct variables', async () => {
          await submitPermission({ includeOptionalFields: true, selectedItem });

          expect(mockCreatePermission).toHaveBeenCalledWith({
            fullPath: contextConfig.fullPath,
            principal: {
              id: principalId,
              type: category,
            },
            actions: ['READ', 'WRITE'],
            expiredAt: '2055-08-12',
          });
        });
      },
    );

    describe('GROUP permissions form', () => {
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
        createComponent({ permissionCategory: 'GROUP', context: contextName });
      });

      it('renders modal', () => {
        expect(findModal().props('visible')).toBe(true);
      });

      it('renders group path input instead of listbox', () => {
        expect(findGroupPathInput().exists()).toBe(true);
        expect(findPrincipalField().exists()).toBe(false);
      });

      it('renders template correctly', () => {
        expect(findModal().props('title')).toBe('Add group');
        expect(findDatepicker().exists()).toBe(true);
        expect(findCheckbox(0).text()).toContain('Read');
        expect(findCheckbox(1).text()).toContain('Write');
        expect(findCheckbox(2).text()).toContain('Delete');
      });

      it('calls the create mutation with the correct variables', async () => {
        await submitPermission({ includeOptionalFields: true, isGroup: true });

        expect(mockCreatePermission).toHaveBeenCalledWith({
          fullPath: contextConfig.fullPath,
          principal: {
            groupPath: 'my-org/sub-group',
            type: 'GROUP',
          },
          actions: ['READ', 'WRITE'],
          expiredAt: '2055-08-12',
        });
      });
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockResolvedValue(contextConfig.mockSuccessResponse);
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('disables submission button by default', () => {
        expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
      });

      it('enables submission button when required fields are provided', async () => {
        await inputRequiredFields();

        expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
      });

      it('emits the refetch event', async () => {
        expect(wrapper.emitted('refetch')).toBeUndefined();

        await submitPermission();

        expect(wrapper.emitted('refetch')).toHaveLength(1);
      });

      it('hides modal and shows toast message on successful submission', async () => {
        expect(mockCreatePermission).toHaveBeenCalledTimes(0);

        await submitPermission();

        expect(mockCreatePermission).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('hide')).toHaveLength(1);
        expect(mockToastShow).toHaveBeenCalledWith(
          'Secrets manager permissions were successfully updated.',
        );
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreatePermission = jest
          .fn()
          .mockResolvedValue(contextConfig.mockErrorResponse('This permission is invalid.'));
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('renders error message from API', async () => {
        await submitPermission();

        expect(createAlert).toHaveBeenCalledWith({ message: 'This permission is invalid.' });
      });
    });

    describe('when submission fails', () => {
      const error = new Error('GraphQL error: API error');
      beforeEach(() => {
        mockCreatePermission = jest.fn().mockRejectedValue(error);
        createComponent({ permissionCategory: 'ROLE', context: contextName });
      });

      it('renders error message with GraphQL prefix stripped', async () => {
        await submitPermission();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error,
        });
      });
    });
  });

  describe('debounced search', () => {
    it('uses debounced search for user listbox in project context', async () => {
      createComponent({ permissionCategory: 'USER' });
      findPrincipalField().vm.$emit('shown');
      await waitForPromises();

      expect(Api.projectUsers).toHaveBeenCalledTimes(1);

      findPrincipalField().vm.$emit('search', 'Foo');
      await waitForDebounce();

      expect(Api.projectUsers).toHaveBeenCalledTimes(2);
      expect(Api.projectUsers).toHaveBeenCalledWith('/path/to/project', 'Foo', undefined);
    });

    it('uses debounced search for user listbox in group context', async () => {
      createComponent({ permissionCategory: 'USER', context: 'group' });
      findPrincipalField().vm.$emit('shown');
      await waitForPromises();

      expect(RestApi.getGroupMembers).toHaveBeenCalledTimes(1);
      expect(RestApi.getGroupMembers).toHaveBeenCalledWith('/path/to/group', false, {
        query: undefined,
      });

      findPrincipalField().vm.$emit('search', 'Foo');
      await waitForDebounce();

      expect(RestApi.getGroupMembers).toHaveBeenCalledTimes(2);
      expect(RestApi.getGroupMembers).toHaveBeenCalledWith('/path/to/group', false, {
        query: 'Foo',
      });
    });
  });
});
