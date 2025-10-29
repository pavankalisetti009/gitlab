import {
  GlButton,
  GlDisclosureDropdownItem,
  GlEmptyState,
  GlKeysetPagination,
  GlLoadingIcon,
  GlLink,
  GlTableLite,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { RouterLinkStub } from '@vue/test-utils';
import { createAlert } from '~/alert';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ENTITY_GROUP, ENTITY_PROJECT, PAGE_SIZE } from 'ee/ci/secrets/constants';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
import SecretsAlertBanner from 'ee/ci/secrets/components/secrets_table/secrets_alert_banner.vue';
import getProjectSecrets from 'ee/ci/secrets/graphql/queries/get_project_secrets.query.graphql';
import getProjectSecretsNeedingRotation from 'ee/ci/secrets/graphql/queries/get_project_secrets_needing_rotation.query.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import { mockEmptySecrets, mockProjectSecretsData } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretsTable component', () => {
  let wrapper;
  let apolloProvider;
  let mockProjectSecretsResponse;
  let mockSecretsNeedingRotationResponse;
  let mockSecretManagerStatus;

  const findDeleteModal = () => wrapper.findComponent(SecretDeleteModal);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findEmptyStateButton = () => findEmptyState().findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findLearnMoreLink = () => wrapper.findComponent(GlLink);
  const findNewSecretButton = () => wrapper.findByTestId('new-secret-button');
  const findSecretsTable = () => wrapper.findComponent(GlTableLite);
  const findSecretsTableRows = () => findSecretsTable().find('tbody').findAll('tr');
  const findSecretDetailsLink = () => wrapper.findByTestId('secret-details-link');
  const findSecretActionsCell = () => wrapper.findComponent(SecretActionsCell);
  const findSecretsAlertBanner = () => wrapper.findComponent(SecretsAlertBanner);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const findDeleteButton = (index) =>
    wrapper
      .findAllComponents(SecretActionsCell)
      .at(index)
      .findAllComponents(GlDisclosureDropdownItem)
      .at(1)
      .find('button');

  const findRotationApproachingIcon = () => wrapper.findByTestId('rotation-approaching-icon');
  const findRotationOverdueIcon = () => wrapper.findByTestId('rotation-overdue-icon');

  const createComponent = async ({ props, isLoading = false } = {}) => {
    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [getProjectSecrets, mockProjectSecretsResponse],
      [getProjectSecretsNeedingRotation, mockSecretsNeedingRotationResponse],
    ];
    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsTable, {
      propsData: {
        fullPath: `path/to/project`,
        context: ENTITY_PROJECT,
        ...props,
      },
      apolloProvider,
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  const mockPaginatedProjectSecrets = ({
    secrets = mockProjectSecretsData,
    offset = 0,
    limit = PAGE_SIZE,
    startCursor = null,
    endCursor = null,
  } = {}) => ({
    data: {
      projectSecrets: {
        edges: secrets,
        nodes: secrets.slice(offset, offset + limit),
        pageInfo: {
          endCursor,
          hasNextPage: Boolean(endCursor),
          hasPreviousPage: Boolean(startCursor),
          startCursor,
          __typename: 'PageInfo',
        },
        __typename: 'ProjectSecretConnection',
      },
    },
  });

  const mockSecretsNeedingRotation = () => ({
    data: {
      projectSecretsNeedingRotation: {
        nodes: [
          {
            name: 'SECRET_1',
            rotationInfo: {
              rotationIntervalDays: 7,
              nextReminderAt: null,
              lastReminderAt: null,
              status: 'APPROACHING',
              __typename: 'SecretRotationInfo',
            },
            __typename: 'ProjectSecret',
          },
        ],
        __typename: 'ProjectSecretConnection',
      },
    },
  });

  beforeEach(() => {
    mockProjectSecretsResponse = jest.fn();
    mockSecretManagerStatus = jest.fn();

    mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockPaginatedProjectSecrets());
    mockSecretsNeedingRotationResponse = jest.fn().mockResolvedValue(mockSecretsNeedingRotation());
  });

  afterEach(() => {
    apolloProvider = null;
  });

  describe('when secrets query is loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('shows loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not show empty state or table', () => {
      expect(findEmptyState().exists()).toBe(false);
      expect(findSecretsTable().exists()).toBe(false);
    });
  });

  describe('when secrets are fetched', () => {
    const secret = mockProjectSecretsData[0].node;

    beforeEach(async () => {
      await createComponent();
    });

    it('does not show the empty state or loading icon', () => {
      expect(findEmptyState().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows a link to the new secret page', () => {
      expect(findNewSecretButton().props('to')).toBe('new');
    });

    it('renders a table of secrets', () => {
      expect(findSecretsTable().exists()).toBe(true);
      expect(findSecretsTableRows()).toHaveLength(mockProjectSecretsData.length);
    });

    it('shows the secret name as a link to the secret details', () => {
      expect(findSecretDetailsLink().text()).toBe(secret.name);
      expect(findSecretDetailsLink().props('to')).toMatchObject({
        name: 'details',
        params: { secretName: secret.name },
      });
    });

    it('passes correct props to actions cell', () => {
      expect(findSecretActionsCell().props()).toMatchObject({
        secretName: secret.name,
      });
    });

    it('hides the delete secret modal', () => {
      expect(findDeleteModal().props('showModal')).toBe(false);
    });

    it('renders learn more link', () => {
      expect(findLearnMoreLink().attributes('href')).toBe(
        '/help/ci/secrets/secrets_manager/_index',
      );
    });
  });

  describe('secrets rotation alert banner', () => {
    it('renders when secrets need rotation', async () => {
      await createComponent();
      expect(findSecretsAlertBanner().exists()).toBe(true);
    });

    it('does not render when no secrets need rotation', async () => {
      mockSecretsNeedingRotationResponse = jest.fn().mockResolvedValue({
        data: {
          projectSecretsNeedingRotation: {
            nodes: [],
            __typename: 'ProjectSecretConnection',
          },
        },
      });
      await createComponent();
      expect(findSecretsAlertBanner().exists()).toBe(false);
    });
  });

  describe('when there are no secrets', () => {
    beforeEach(async () => {
      mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockEmptySecrets);
      await createComponent();
    });

    it('shows empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not show table or loading icon', () => {
      expect(findSecretsTable().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders link to secret form', () => {
      expect(findEmptyStateButton().attributes('href')).toBe('new');
    });
  });

  describe('when secrets query fails', () => {
    const error = new Error('Permission denied.');

    beforeEach(async () => {
      mockProjectSecretsResponse = jest.fn().mockRejectedValue(error);
      await createComponent();
    });

    it('renders error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'An error occurred while fetching secrets. Please make sure you have the proper permissions, or try again.',
        captureError: true,
        error,
      });
    });
  });

  describe('pagination', () => {
    it.each`
      startCursor | endCursor | description          | paginationShouldExist
      ${'MQ'}     | ${'NQ'}   | ${'renders'}         | ${true}
      ${'MQ'}     | ${null}   | ${'renders'}         | ${true}
      ${null}     | ${'NQ'}   | ${'renders'}         | ${true}
      ${null}     | ${null}   | ${'does not render'} | ${false}
    `(
      '$description when there are startCursor = $startCursor and endCursor = $endCursor',
      async ({ startCursor, endCursor, paginationShouldExist }) => {
        mockProjectSecretsResponse.mockResolvedValue(
          mockPaginatedProjectSecrets({
            startCursor,
            endCursor,
          }),
        );

        await createComponent();

        expect(findPagination().exists()).toBe(paginationShouldExist);

        if (paginationShouldExist) {
          expect(findPagination().props('startCursor')).toBe(startCursor);
          expect(findPagination().props('endCursor')).toBe(endCursor);
          expect(findPagination().props('hasPreviousPage')).toBe(Boolean(startCursor));
          expect(findPagination().props('hasNextPage')).toBe(Boolean(endCursor));
        }
      },
    );

    it('calls query with the correct parameters when moving between pages', async () => {
      // initial call
      mockProjectSecretsResponse.mockResolvedValue(
        mockPaginatedProjectSecrets({
          startCursor: null,
          endCursor: 'Mw',
        }),
      );

      await createComponent({ props: { pageSize: 3 } });

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        projectPath: 'path/to/project',
        limit: 3,
      });

      // next page
      mockProjectSecretsResponse.mockResolvedValue(
        mockPaginatedProjectSecrets({
          startCursor: 'MQ',
          endCursor: 'NA',
        }),
      );

      findPagination().vm.$emit('next');
      await waitForPromises();
      await nextTick();

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        after: 'Mw',
        before: null,
        projectPath: 'path/to/project',
        limit: 3,
      });

      // previous page
      findPagination().vm.$emit('prev');
      await waitForPromises();
      await nextTick();

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        after: null,
        before: 'MQ',
        projectPath: 'path/to/project',
        limit: 3,
      });
    });
  });

  describe('rotation reminder icons', () => {
    it('shows warning icon for APPROACHING status', async () => {
      const approachingSecret = [mockProjectSecretsData[0]]; // First secret has APPROACHING status
      mockProjectSecretsResponse = jest
        .fn()
        .mockResolvedValue(mockPaginatedProjectSecrets({ secrets: approachingSecret }));
      await createComponent();

      const approachingIcon = findRotationApproachingIcon();
      expect(approachingIcon.exists()).toBe(true);
      expect(approachingIcon.props('name')).toBe('warning');
      expect(approachingIcon.props('variant')).toBe('warning');
      expect(approachingIcon.attributes('title')).toBe(
        'Rotation reminder: This secret needs to be updated soon.',
      );
    });

    it('shows warning-solid icon for OVERDUE status', async () => {
      const overdueSecret = [mockProjectSecretsData[1]]; // Second secret has OVERDUE status
      mockProjectSecretsResponse = jest
        .fn()
        .mockResolvedValue(mockPaginatedProjectSecrets({ secrets: overdueSecret }));
      await createComponent();

      const overdueIcon = findRotationOverdueIcon();
      expect(overdueIcon.exists()).toBe(true);
      expect(overdueIcon.props('name')).toBe('warning-solid');
      expect(overdueIcon.props('variant')).toBe('danger');
      expect(overdueIcon.attributes('title')).toBe('Rotation overdue');
    });

    it('does not show rotation icons when no rotation info', async () => {
      const secretWithNoRotation = [mockProjectSecretsData[2]]; // third secret has no rotation status
      mockProjectSecretsResponse = jest
        .fn()
        .mockResolvedValue(mockPaginatedProjectSecrets({ secrets: secretWithNoRotation }));
      await createComponent();

      expect(findRotationApproachingIcon().exists()).toBe(false);
      expect(findRotationOverdueIcon().exists()).toBe(false);
    });
  });

  describe('delete secret modal', () => {
    describe('when deleting a secret', () => {
      beforeEach(async () => {
        await createComponent();

        findDeleteButton(0).trigger('click');
        await nextTick();
      });

      it('shows delete modal when clicking on "Delete" action', () => {
        expect(findDeleteModal().props('showModal')).toBe(true);
      });

      it('refetches secrets and hides modal when secret is deleted', async () => {
        expect(mockProjectSecretsResponse).toHaveBeenCalledTimes(1);

        findDeleteModal().vm.$emit('refetch-secrets');
        await nextTick();

        expect(findDeleteModal().props('showModal')).toBe(false);
        expect(mockProjectSecretsResponse).toHaveBeenCalledTimes(2);
      });
    });

    describe('when re-opening the modal', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('resets the secret name', async () => {
        findDeleteButton(0).trigger('click');
        await nextTick();

        expect(findDeleteModal().props('secretName')).toBe('SECRET_1');

        findDeleteModal().vm.$emit('hide');
        findDeleteButton(1).trigger('click');
        await nextTick();

        expect(findDeleteModal().props('secretName')).toBe('SECRET_2');
      });
    });
  });

  describe('secretsNeedingRotation query', () => {
    beforeEach(() => {
      createAlert.mockClear();
    });

    it('fetches secrets needing rotation with correct variables', async () => {
      await createComponent();

      expect(mockSecretsNeedingRotationResponse).toHaveBeenCalledWith({
        projectPath: 'path/to/project',
      });
    });

    it('handles errors when fetching secrets needing rotation', async () => {
      const error = new Error('Network error occurred');
      mockSecretsNeedingRotationResponse = jest.fn().mockRejectedValue(error);

      await createComponent();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching secrets needing rotation. Please try again.',
        captureError: true,
        error,
      });
    });
  });

  describe('group context', () => {
    beforeEach(async () => {
      await createComponent({ props: { context: ENTITY_GROUP } });
    });

    it('skips project secrets query and project secrets rotation query', () => {
      expect(mockProjectSecretsResponse).not.toHaveBeenCalled();
      expect(mockSecretsNeedingRotationResponse).not.toHaveBeenCalled();
    });

    it('shows empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });
  });
});
