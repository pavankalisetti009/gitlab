import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLoadingIcon,
  GlModal,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EDIT_ROUTE_NAME, SECRET_ROTATION_STATUS } from 'ee/ci/secrets/constants';
import getSecretDetailsQuery from 'ee/ci/secrets/graphql/queries/get_secret_details.query.graphql';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
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
    fullPath: '/path/to/project',
    secretName: 'SECRET_KEY',
  };

  const createComponent = async ({
    props = {},
    stubs = { GlDisclosureDropdown, GlDisclosureDropdownItem, SecretDeleteModal },
    isLoading = false,
    mountFn = shallowMountExtended,
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
      },
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDeleteButton = () =>
    findDisclosureDropdown().findAllComponents(GlDisclosureDropdownItem).at(0).find('button');
  const findDeleteModal = () => wrapper.findComponent(GlModal);
  const findSecretDeleteModalComponent = () => wrapper.findComponent(SecretDeleteModal);
  const findEditButton = () => wrapper.findByTestId('secret-edit-button');
  const findKey = () => wrapper.find('h1');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRotationAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    mockSecretQuery = jest.fn();
    mockSecretQuery.mockResolvedValue(mockProjectSecretQueryResponse());
  });

  describe('when query is loading', () => {
    it('renders loading icon', () => {
      createComponent({ isLoading: true });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  // We also get a GraphQL error when secret doesn't exist
  // so this also covers that use case
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

  describe('when query succeeds', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders action buttons', () => {
      expect(findEditButton().exists()).toBe(true);
      expect(findDeleteButton().exists()).toBe(true);
    });

    it('renders secret details', () => {
      expect(findKey().text()).toBe('APP_PWD');
    });

    it('shows a link to the edit secret page', async () => {
      createComponent();
      await waitForPromises();

      findEditButton().vm.$emit('click');
      expect(mockRouter.push).toHaveBeenCalledWith({
        name: EDIT_ROUTE_NAME,
        params: { secretName: defaultProps.secretName },
      });
    });
  });

  describe('delete secrets modal', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders modal when clicking on the delete button', async () => {
      expect(findDeleteModal().props('visible')).toBe(false);

      findDeleteButton().trigger('click');
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(true);
    });

    it('can reopen modal after it is hidden', async () => {
      findDeleteButton().trigger('click');
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(true);

      findSecretDeleteModalComponent().vm.$emit('hide');
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(false);

      findDeleteButton().trigger('click');
      await nextTick();

      expect(findDeleteModal().props('visible')).toBe(true);
    });
  });

  describe('rotation alert banner', () => {
    describe('when secret has no rotation info', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('does not render rotation alert', () => {
        expect(findRotationAlert().exists()).toBe(false);
      });
    });

    describe('when secret rotation status is approaching', () => {
      const nextReminderAt = '2026-01-15T10:30:00Z';

      beforeEach(async () => {
        const customSecret = {
          rotationInfo: {
            rotationIntervalDays: 7,
            status: SECRET_ROTATION_STATUS.approaching,
            nextReminderAt,
            __typename: 'SecretRotationInfo',
          },
        };

        mockSecretQuery.mockResolvedValue(mockProjectSecretQueryResponse({ customSecret }));
        await createComponent();
      });

      it('renders rotation alert with approaching status and message', () => {
        const alert = findRotationAlert();
        expect(alert.props('variant')).toBe('warning');
        expect(alert.props('title')).toBe('Rotation reminder');
        expect(alert.text()).toBe('Update this secret by Jan 15, 2026 to maintain security.');
      });

      it('displays formatted date in alert message', () => {
        const alert = findRotationAlert();
        expect(alert.text()).toContain('Update this secret by Jan 15, 2026 to maintain security.');
      });
    });

    describe('when secret rotation status is overdue', () => {
      beforeEach(async () => {
        const customSecret = {
          rotationInfo: {
            rotationIntervalDays: 7,
            status: SECRET_ROTATION_STATUS.overdue,
            nextReminderAt: '2026-01-15T10:30:00Z',
            __typename: 'SecretRotationInfo',
          },
        };

        mockSecretQuery.mockResolvedValue(mockProjectSecretQueryResponse({ customSecret }));
        await createComponent();
      });

      it('renders rotation alert with overdue status and message', () => {
        const alert = findRotationAlert();
        expect(alert.props('variant')).toBe('warning');
        expect(alert.props('title')).toBe('Secret overdue for rotation');
        expect(alert.text()).toBe(
          'This secret has not been rotated after the configured rotation reminder interval.',
        );
      });
    });

    describe('when secret has OK rotation status', () => {
      beforeEach(async () => {
        const customSecret = {
          rotationInfo: {
            status: 'OK',
            nextReminderAt: '2024-01-15T10:30:00Z',
            __typename: 'SecretRotationInfo',
          },
        };
        mockSecretQuery.mockResolvedValue(mockProjectSecretQueryResponse({ customSecret }));
        await createComponent();
      });

      it('does not render rotation alert', () => {
        expect(findRotationAlert().exists()).toBe(false);
      });
    });
  });
});
