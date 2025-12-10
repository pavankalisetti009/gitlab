import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlExperimentBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogFlowsShow from 'ee/ai/catalog/pages/ai_catalog_flows_show.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import {
  TRACK_EVENT_TYPE_FLOW,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  VERSION_PINNED,
  VERSION_LATEST,
} from 'ee/ai/catalog/constants';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import updateAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import reportAiCatalogItemMutation from 'ee/ai/catalog/graphql/mutations/report_ai_catalog_item.mutation.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  mockAiCatalogFlowResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockUpdateAiCatalogItemConsumerSuccess,
  mockUpdateAiCatalogItemConsumerError,
  mockItemConfigurationForGroup,
  mockCatalogFlowDeleteErrorResponse,
  mockCatalogFlowDeleteResponse,
  mockReportAiCatalogItemSuccessMutation,
  mockReportAiCatalogItemErrorMutation,
  mockFlow,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockFlowConfigurationForProject,
  mockVersionProp,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogFlowsShow', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    version: mockVersionProp,
    aiCatalogFlow: {
      ...mockFlow,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    },
  };

  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const createAiCatalogItemConsumerHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);
  const updateAiCatalogItemConsumerHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogItemConsumerSuccess);
  const reportAiCatalogItemMutationHandler = jest
    .fn()
    .mockResolvedValue(mockReportAiCatalogItemSuccessMutation);
  const deleteFlowMutationHandler = jest.fn().mockResolvedValue(mockCatalogFlowDeleteResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const routeParams = { id: '1' };
  const mockToast = {
    show: jest.fn(),
  };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
      [deleteAiCatalogFlowMutation, deleteFlowMutationHandler],
      [reportAiCatalogItemMutation, reportAiCatalogItemMutationHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
      [updateAiCatalogItemConsumer, updateAiCatalogItemConsumerHandler],
    ]);
    // refetchQueries will only refetch active queries, so simply registering a query handler is not enough.
    // We need to call `subscribe()` to make the query observable and avoid "Unknown query" errors.
    // This simulates what the actual code in VueApollo is doing when adding a smart query.
    // Docs: https://www.apollographql.com/docs/react/api/core/ApolloClient/#watchquery
    mockApollo.clients.defaultClient
      .watchQuery({
        query: aiCatalogFlowQuery,
      })
      .subscribe();

    wrapper = shallowMountExtended(AiCatalogFlowsShow, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        isGlobal: false,
        projectId: '1',
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $toast: mockToast,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
  const findItemView = () => wrapper.findComponent(AiCatalogItemView);
  const findFoundationalIcon = () => wrapper.findComponent(FoundationalIcon);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findUpdateAlert = () => wrapper.findComponent(GlAlert);
  const findPrimaryUpdateButton = () => wrapper.findByTestId('flows-show-primary-button');
  const findSecondaryUpdateButton = () => wrapper.findByTestId('flows-show-secondary-button');

  beforeEach(() => {
    createComponent();
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toEqual({
      ...mockFlow,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    });
  });

  it('renders item view', () => {
    expect(findItemView().props('item')).toEqual({
      ...mockFlow,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    });
  });

  describe('Page Heading', () => {
    it('renders page heading with correct title and description', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain(mockFlow.name);
    });

    it('renders experiment badge', () => {
      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('foundational flow', () => {
    describe('when flow is foundational', () => {
      beforeEach(() => {
        createComponent({
          props: {
            aiCatalogFlow: {
              ...mockFlow,
              foundational: true,
              configurationForProject: mockFlowConfigurationForProject,
            },
          },
        });
      });

      it('renders foundational icon with correct resource-id and itemType', () => {
        const foundationalIcon = findFoundationalIcon();

        expect(foundationalIcon.props('resourceId')).toBe(mockFlow.id);
        expect(foundationalIcon.props('itemType')).toBe(mockFlow.itemType);
      });

      it('displays foundational icon badge next to flow name', () => {
        expect(findFoundationalIcon().exists()).toBe(true);
      });

      it('renders foundational icon in the same container as flow name', () => {
        const headingContainer = wrapper.find('[class*="gl-flex"]');
        expect(headingContainer.findComponent(FoundationalIcon).exists()).toBe(true);
      });
    });

    describe('when flow is not foundational', () => {
      it('does not render foundational icon', () => {
        expect(findFoundationalIcon().exists()).toBe(false);
      });
    });
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_FLOW },
        undefined,
      );
    });
  });

  describe('on adding flow to project', () => {
    const addFlowToProject = () => findItemActions().vm.$emit('add-to-target', { projectId: '1' });

    it('calls create consumer mutation for flow', () => {
      addFlowToProject();

      expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
        input: {
          itemId: mockFlow.id,
          target: { projectId: '1' },
          parentItemConsumerId: mockItemConfigurationForGroup.id,
        },
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        addFlowToProject();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow enabled in Test.');
      });

      it('refetches flow data', () => {
        expect(mockFlowQueryHandler).toHaveBeenCalled();
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        createAiCatalogItemConsumerHandler.mockResolvedValue(
          mockAiCatalogItemConsumerCreateErrorResponse,
        );
        addFlowToProject();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('custom error'));
        addFlowToProject();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Could not enable flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on deleting a flow', () => {
    const forceHardDelete = false;
    const deleteFlow = () => findItemActions().props('deleteFn')(forceHardDelete);

    it('calls delete mutation for flow', () => {
      deleteFlow();

      expect(deleteFlowMutationHandler).toHaveBeenCalledWith({ id: mockFlow.id, forceHardDelete });
    });

    describe('when request succeeds', () => {
      it('shows a toast message', async () => {
        deleteFlow();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Flow deleted.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows alert with error', async () => {
        deleteFlowMutationHandler.mockResolvedValue(mockCatalogFlowDeleteErrorResponse);

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. You do not have permission to delete this AI flow.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows alert with error and captures exception', async () => {
        deleteFlowMutationHandler.mockRejectedValue(new Error('Request failed'));

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. Error: Request failed',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on disabling a flow', () => {
    const disableFlow = () => findItemActions().props('disableFn')();

    it('calls disable mutation for flow', () => {
      disableFlow();

      expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
        id: mockFlowConfigurationForProject.id,
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        disableFlow();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Flow disabled in this project.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        deleteItemConsumerMutationHandler.mockResolvedValue(
          mockAiCatalogItemConsumerDeleteErrorResponse,
        );
        disableFlow();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable flow. You do not have permission to disable this item.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        deleteItemConsumerMutationHandler.mockRejectedValue(new Error('custom error'));
        disableFlow();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable flow. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('when reporting the flow', () => {
    const input = {
      reason: 'SPAM',
      body: 'This is a test report',
    };

    const reportFlow = () => findItemActions().vm.$emit('report-item', input);

    it('sends a report request', () => {
      reportFlow();

      expect(reportAiCatalogItemMutationHandler).toHaveBeenCalledTimes(1);
      expect(reportAiCatalogItemMutationHandler).toHaveBeenCalledWith({
        input: {
          id: mockFlow.id,
          ...input,
        },
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        reportFlow();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Report submitted successfully.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        reportAiCatalogItemMutationHandler.mockResolvedValue(mockReportAiCatalogItemErrorMutation);
        reportFlow();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        reportAiCatalogItemMutationHandler.mockRejectedValue(new Error('custom error'));
        reportFlow();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to report flow. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('version update behaviour', () => {
    const mockVersionPropWithFn = {
      isUpdateAvailable: true,
      activeVersionKey: VERSION_LATEST,
      setActiveVersionKey: jest.fn(),
    };

    it('shows only the "View latest version" button when update is available', () => {
      createComponent({
        props: {
          version: {
            ...mockVersionPropWithFn,
            activeVersionKey: VERSION_PINNED,
          },
        },
      });

      expect(findUpdateAlert().exists()).toBe(true);
      expect(findPrimaryUpdateButton().text()).toEqual('View latest version');
      expect(findSecondaryUpdateButton().exists()).toEqual(false);
    });

    it('should show a "View enabled version" and "Update to vXX" buttons when latest version is active', async () => {
      createComponent({
        props: {
          version: mockVersionPropWithFn,
        },
      });
      await waitForPromises();

      expect(findPrimaryUpdateButton().text()).toEqual('Update to v1.0.0-draft');
      expect(findSecondaryUpdateButton().text()).toEqual('View enabled version');
    });

    describe('when updating version', () => {
      const updateVersion = () => findPrimaryUpdateButton().vm.$emit('click');

      const readyForUpdateComponent = () => {
        createComponent({
          props: {
            version: mockVersionPropWithFn,
          },
        });
      };

      beforeEach(async () => {
        updateAiCatalogItemConsumerHandler.mockResolvedValue(
          mockUpdateAiCatalogItemConsumerSuccess,
        );

        readyForUpdateComponent();
        await waitForPromises();
      });

      it('calls the update mutation with correct version prefix when button is clicked', async () => {
        await updateVersion();
        await waitForPromises();

        expect(updateAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
          input: {
            id: mockFlowConfigurationForProject.id,
            pinnedVersionPrefix: '1.0.0',
          },
        });
      });

      it('shows error alert when it fails', async () => {
        updateAiCatalogItemConsumerHandler.mockResolvedValue(mockUpdateAiCatalogItemConsumerError);
        updateVersion();
        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Could not update flow in the project.',
        ]);
      });

      it('shows success toast when it succeeds', async () => {
        await updateVersion();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Flow is now at version 1.0.0-draft.');
      });
    });
  });
});
