import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import { TRACK_EVENT_TYPE_AGENT, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import reportAiCatalogItem from 'ee/ai/catalog/graphql/mutations/report_ai_catalog_item.mutation.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAgent,
  mockConfigurationForProject,
  mockAiCatalogAgentResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockCatalogAgentDeleteResponse,
  mockCatalogAgentDeleteErrorResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockReportAiCatalogItemSuccessMutation,
  mockReportAiCatalogItemErrorMutation,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogAgentsShow', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };

  const defaultProps = {
    aiCatalogAgent: { ...mockAgent, configurationForProject: mockConfigurationForProject },
  };

  const routeParams = { id: '1' };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const reportAiCatalogItemMock = jest
    .fn()
    .mockResolvedValue(mockReportAiCatalogItemSuccessMutation);
  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const createAiCatalogItemConsumerHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);
  const deleteAgentMutationHandler = jest.fn().mockResolvedValue(mockCatalogAgentDeleteResponse);
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([
      [reportAiCatalogItem, reportAiCatalogItemMock],
      [aiCatalogAgentQuery, mockAgentQueryHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
      [deleteAiCatalogAgentMutation, deleteAgentMutationHandler],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);
    // refetchQueries will only refetch active queries, so simply registering a query handler is not enough.
    // We need to call `subscribe()` to make the query observable and avoid "Unknown query" errors.
    // This simulates what the actual code in VueApollo is doing when adding a smart query.
    // Docs: https://www.apollographql.com/docs/react/api/core/ApolloClient/#watchquery
    mockApollo.clients.defaultClient
      .watchQuery({
        query: aiCatalogAgentQuery,
      })
      .subscribe();

    wrapper = shallowMount(AiCatalogAgentsShow, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
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

  beforeEach(() => {
    createComponent();
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toEqual({
      ...mockAgent,
      configurationForProject: mockConfigurationForProject,
    });
  });

  it('renders item view', () => {
    expect(findItemView().props('item')).toEqual({
      ...mockAgent,
      configurationForProject: mockConfigurationForProject,
    });
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_AGENT },
        undefined,
      );
    });
  });

  describe('on adding agent to project', () => {
    const addAgentToProject = () => findItemActions().vm.$emit('add-to-target', { projectId: '1' });

    it('calls create consumer mutation for agent', () => {
      addAgentToProject();

      expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
        input: {
          itemId: mockAgent.id,
          target: { projectId: '1' },
        },
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        addAgentToProject();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Agent enabled in Test.');
      });

      it('refetches agent data', () => {
        expect(mockAgentQueryHandler).toHaveBeenCalled();
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        createAiCatalogItemConsumerHandler.mockResolvedValue(
          mockAiCatalogItemConsumerCreateErrorResponse,
        );
        addAgentToProject();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('custom error'));
        addAgentToProject();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Could not enable agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on deleting an agent', () => {
    const deleteAgent = () => findItemActions().props('deleteFn')();

    it('calls delete mutation for agent', () => {
      deleteAgent();

      expect(deleteAgentMutationHandler).toHaveBeenCalledWith({
        id: mockAgent.id,
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        deleteAgent();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agent deleted.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        deleteAgentMutationHandler.mockResolvedValue(mockCatalogAgentDeleteErrorResponse);
        deleteAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete agent. You do not have permission to delete this AI agent.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        deleteAgentMutationHandler.mockRejectedValue(new Error('custom error'));
        deleteAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete agent. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('on disabling an agent', () => {
    const disableAgent = () => findItemActions().props('disableFn')();

    it('calls disable mutation for agent', () => {
      disableAgent();

      expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
        id: mockConfigurationForProject.id,
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        disableAgent();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agent disabled in this project.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        deleteItemConsumerMutationHandler.mockResolvedValue(
          mockAiCatalogItemConsumerDeleteErrorResponse,
        );
        disableAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable agent. You do not have permission to disable this item.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        deleteItemConsumerMutationHandler.mockRejectedValue(new Error('custom error'));
        disableAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable agent. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });

  describe('when reporting the agent', () => {
    const input = {
      reason: 'SPAM',
      body: 'This is a test report',
    };

    const reportAgent = () => findItemActions().vm.$emit('report-item', input);

    it('sends a report request', () => {
      reportAgent();

      expect(reportAiCatalogItemMock).toHaveBeenCalledTimes(1);
      expect(reportAiCatalogItemMock).toHaveBeenCalledWith({
        input: {
          id: mockAgent.id,
          ...input,
        },
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        reportAgent();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Report submitted successfully.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        reportAiCatalogItemMock.mockResolvedValue(mockReportAiCatalogItemErrorMutation);
        reportAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows error alert and captures exception', async () => {
        reportAiCatalogItemMock.mockRejectedValue(new Error('custom error'));
        reportAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to report agent. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});
