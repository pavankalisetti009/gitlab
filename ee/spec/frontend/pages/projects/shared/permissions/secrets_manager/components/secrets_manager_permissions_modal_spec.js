import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlDatepicker, GlFormCheckbox, GlModal } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import Api from '~/api';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsModal from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_modal.vue';
import createSecretsPermissionMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/create_secrets_permission.mutation.graphql';
import {
  MOCK_USERS_API,
  MOCK_GROUPS_API,
  mockCreatePermissionResponse,
  mockCreatePermissionErrorResponse,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/api');
const mockToastShow = jest.fn();
Vue.use(VueApollo);

describe('SecretsManagerPermissionsModal', () => {
  let wrapper;
  let axiosMock;
  let mockApollo;
  let mockCreatePermission;

  const createComponent = ({ permissionCategory = null } = {}) => {
    mockApollo = createMockApollo([[createSecretsPermissionMutation, mockCreatePermission]]);

    wrapper = shallowMountExtended(PermissionsModal, {
      apolloProvider: mockApollo,
      provide: {
        fullPath: '/path/to/project',
        projectId: 123,
      },
      propsData: {
        permissionCategory,
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

  const inputRequiredFields = async (selectedItem = 'MAINTAINER') => {
    // expiredAt is optional
    findCheckbox(0).vm.$emit('input', true);
    findCheckbox(1).vm.$emit('input', true);
    findPrincipalField().vm.$emit('select', selectedItem);

    await nextTick();
  };

  const submitPermission = async ({
    includeOptionalFields = false,
    selectedItem = 'MAINTAINER',
  } = {}) => {
    if (includeOptionalFields) {
      findDatepicker().vm.$emit('input', new Date('2055-08-12'));
    }

    await inputRequiredFields(selectedItem);
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
  };

  const waitForDebounce = () => {
    jest.runOnlyPendingTimers();
    return waitForPromises();
  };

  beforeEach(() => {
    // mock users API
    axiosMock = new MockAdapter(axios);
    jest.spyOn(Api, 'projectUsers').mockResolvedValue(MOCK_USERS_API);

    // mock groups API
    const mockUrl = '/-/autocomplete/project_groups.json';
    axiosMock.onGet(mockUrl).replyOnce(HTTP_STATUS_OK, MOCK_GROUPS_API);

    // mock mutation response
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
      expect(findCheckbox(3).attributes('disabled')).toBeDefined();
    });

    it('enables all checkboxes when the first checkbox is selected', async () => {
      findCheckbox(0).vm.$emit('input', true);
      await nextTick();

      expect(findCheckbox(1).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(2).attributes('disabled')).toBeUndefined();
      expect(findCheckbox(3).attributes('disabled')).toBeUndefined();
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
  const GROUP_ITEMS = ['Organization', 'test-org'];
  const ROLE_ITEMS = ['Reporter', 'Developer', 'Maintainer'];

  describe.each`
    category   | title          | fieldItems     | selectedItem    | principalId
    ${'USER'}  | ${'Add user'}  | ${USER_ITEMS}  | ${'john.doe'}   | ${2}
    ${'GROUP'} | ${'Add group'} | ${GROUP_ITEMS} | ${22}           | ${22}
    ${'ROLE'}  | ${'Add role'}  | ${ROLE_ITEMS}  | ${'MAINTAINER'} | ${40}
  `('$category permissions form', ({ category, title, fieldItems, selectedItem, principalId }) => {
    beforeEach(async () => {
      createComponent({ permissionCategory: category });
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
      expect(findCheckbox(1).text()).toContain('Create');
      expect(findCheckbox(2).text()).toContain('Update');
      expect(findCheckbox(3).text()).toContain('Delete');
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
        projectPath: '/path/to/project',
        principal: {
          id: principalId,
          type: category,
        },
        permissions: ['read', 'create'],
        expiredAt: '2055-08-12',
      });
    });
  });

  describe('debounced search', () => {
    it('uses debounced search for user listbox', async () => {
      createComponent({ permissionCategory: 'USER' });
      findPrincipalField().vm.$emit('shown');
      await waitForPromises();

      expect(Api.projectUsers).toHaveBeenCalledTimes(1);

      findPrincipalField().vm.$emit('search', 'Foo');
      await waitForDebounce();

      expect(Api.projectUsers).toHaveBeenCalledTimes(2);
      expect(Api.projectUsers).toHaveBeenCalledWith('/path/to/project', 'Foo', undefined);
    });

    it('uses debounced search for group listbox', async () => {
      jest.spyOn(axios, 'get');

      createComponent({ permissionCategory: 'GROUP' });
      findPrincipalField().vm.$emit('shown');
      await waitForPromises();

      expect(axios.get).toHaveBeenCalledTimes(1);

      findPrincipalField().vm.$emit('search', 'Foo');
      await waitForDebounce();

      expect(axios.get).toHaveBeenCalledTimes(2);
      expect(axios.get).toHaveBeenCalledWith('/-/autocomplete/project_groups.json', {
        params: {
          project_id: 123,
          search: 'Foo',
          with_project_access: true,
        },
      });
    });
  });

  describe('when submission is successful', () => {
    beforeEach(() => {
      createComponent({ permissionCategory: 'ROLE' });
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
        .mockResolvedValue(mockCreatePermissionErrorResponse('This permission is invalid.'));
      createComponent({ permissionCategory: 'ROLE' });
    });

    it('renders error message from API', async () => {
      await submitPermission();

      expect(createAlert).toHaveBeenCalledWith({ message: 'This permission is invalid.' });
    });
  });

  describe('when submission fails', () => {
    const error = new Error();
    beforeEach(() => {
      mockCreatePermission.mockRejectedValue();
      createComponent({ permissionCategory: 'ROLE' });
    });

    it('renders error message', async () => {
      await submitPermission();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to create secrets manager permission. Please try again.',
        captureError: true,
        error,
      });
    });
  });
});
