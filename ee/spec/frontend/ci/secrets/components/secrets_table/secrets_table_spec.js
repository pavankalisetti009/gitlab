import {
  GlAlert,
  GlButton,
  GlEmptyState,
  GlLoadingIcon,
  GlKeysetPagination,
  GlTableLite,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  NEW_ROUTE_NAME,
  PAGE_SIZE,
  POLL_INTERVAL,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';
import getProjectSecrets from 'ee/ci/secrets/graphql/queries/get_project_secrets.query.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import {
  mockEmptySecrets,
  mockProjectSecretsData,
  secretManagerStatusResponse,
} from '../../mock_data';

Vue.use(VueApollo);

describe('SecretsTable component', () => {
  let wrapper;
  let apolloProvider;
  let mockProjectSecretsResponse;
  let mockSecretManagerStatus;

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findEmptyStateButton = () => findEmptyState().findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNewSecretButton = () => wrapper.findByTestId('new-secret-button');
  const findSecretsTable = () => wrapper.findComponent(GlTableLite);
  const findSecretsTableRows = () => findSecretsTable().find('tbody').findAll('tr');
  const findSecretDetailsLink = () => wrapper.findByTestId('secret-details-link');
  const findSecretActionsCell = () => wrapper.findComponent(SecretActionsCell);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const createComponent = async ({ props } = {}) => {
    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [getProjectSecrets, mockProjectSecretsResponse],
    ];
    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsTable, {
      propsData: {
        fullPath: `path/to/project`,
        ...props,
      },
      apolloProvider,
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });

    await waitForPromises();
  };

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (status) => {
    mockSecretManagerStatus.mockResolvedValue(secretManagerStatusResponse(status));
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  const mockPaginatedProjectSecrets = ({
    offset = 0,
    limit = PAGE_SIZE,
    startCursor = null,
    endCursor = null,
  } = {}) => ({
    data: {
      projectSecrets: {
        edges: mockProjectSecretsData,
        nodes: mockProjectSecretsData.slice(offset, offset + limit),
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

  beforeEach(() => {
    mockProjectSecretsResponse = jest.fn();
    mockSecretManagerStatus = jest.fn();

    mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockPaginatedProjectSecrets());
    mockSecretManagerStatus.mockResolvedValue(
      secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE),
    );
  });

  afterEach(() => {
    apolloProvider = null;
  });

  describe('Secret Manager Status', () => {
    it('shows loading icon while status is being fetched', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findSecretsTable().exists()).toBe(false);
    });

    describe('when status is PROVISIONING', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING),
        );

        await createComponent();
      });

      it('shows alert notice when status is provisioning', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findSecretsTable().exists()).toBe(false);
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().props('dismissible')).toBe(false);
      });

      it('polls for status while provisioning', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_PROVISIONING);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
      });
    });

    describe('when status is ACTIVE', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('shows table when status is active', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findAlert().exists()).toBe(false);
        expect(findSecretsTable().exists()).toBe(true);
      });

      it('stops polling for status', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe('project secrets table', () => {
    const secret = mockProjectSecretsData[0].node;

    beforeEach(async () => {
      await createComponent();
    });

    it('does not show the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('shows a link to the new secret page', () => {
      expect(findNewSecretButton().attributes('to')).toBe(NEW_ROUTE_NAME);
    });

    it('renders a table of secrets', () => {
      expect(findSecretsTable().exists()).toBe(true);
      expect(findSecretsTableRows().length).toBe(mockProjectSecretsData.length);
    });

    it('shows the secret name as a link to the secret details', () => {
      expect(findSecretDetailsLink().text()).toBe(secret.name);
      expect(findSecretDetailsLink().props('to')).toMatchObject({
        name: DETAILS_ROUTE_NAME,
        params: { secretName: secret.name },
      });
    });

    it('passes correct props to actions cell', () => {
      expect(findSecretActionsCell().props()).toMatchObject({
        detailsRoute: {
          name: EDIT_ROUTE_NAME,
          params: { name: secret.name },
        },
      });
    });
  });

  describe('when there are no secrets', () => {
    beforeEach(async () => {
      mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockEmptySecrets);
      await createComponent();
    });

    it('shows empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findSecretsTable().exists()).toBe(false);
    });

    it('renders link to secret form', () => {
      expect(findEmptyStateButton().attributes('href')).toBe('new');
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
});
