import createMockApollo from 'helpers/mock_apollo_helper';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import deleteAgenticWorkflowMutation from 'ee/ai/graphql/delete_agentic_workflow.mutation.graphql';
import getWorkflowEventsQuery from 'ee/ai/graphql/get_workflow_events.query.graphql';
import { ApolloUtils } from 'ee/ai/duo_agentic_chat/utils/apollo_utils';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
} from 'ee/ai/constants';
import { parseGid } from '~/graphql_shared/utils';
import { MULTI_THREADED_CONVERSATION_TYPE } from 'ee/ai/tanuki_bot/constants';
import {
  MOCK_PROJECT_ID,
  MOCK_NAMESPACE_ID,
  MOCK_WORKFLOW_ID,
  MOCK_GOAL,
  MOCK_ACTIVE_THREAD,
  MOCK_WORKFLOW_MUTATION_RESPONSE,
  MOCK_DELETE_WORKFLOW_RESPONSE,
  MOCK_FETCH_WORKFLOW_EVENTS_RESPONSE,
} from './mock_data';

jest.mock('~/graphql_shared/utils', () => ({
  parseGid: jest.fn(),
}));

describe('ApolloUtils', () => {
  let apolloProvider;
  let duoWorkflowMutationHandlerMock;
  let deleteWorkflowMutationHandlerMock;
  let getWorkflowEventsQueryHandlerMock;

  beforeEach(() => {
    jest.clearAllMocks();
    parseGid.mockReturnValue({ id: '789' });

    duoWorkflowMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_WORKFLOW_MUTATION_RESPONSE);
    deleteWorkflowMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_DELETE_WORKFLOW_RESPONSE);
    getWorkflowEventsQueryHandlerMock = jest
      .fn()
      .mockResolvedValue(MOCK_FETCH_WORKFLOW_EVENTS_RESPONSE);

    apolloProvider = createMockApollo([
      [duoWorkflowMutation, duoWorkflowMutationHandlerMock],
      [deleteAgenticWorkflowMutation, deleteWorkflowMutationHandlerMock],
      [getWorkflowEventsQuery, getWorkflowEventsQueryHandlerMock],
    ]);
  });

  describe('createWorkflow', () => {
    it.each`
      description                            | projectId          | namespaceId
      ${'projectId only'}                    | ${MOCK_PROJECT_ID} | ${undefined}
      ${'namespaceId only'}                  | ${undefined}       | ${MOCK_NAMESPACE_ID}
      ${'both projectId and namespaceId'}    | ${MOCK_PROJECT_ID} | ${MOCK_NAMESPACE_ID}
      ${'neither projectId nor namespaceId'} | ${undefined}       | ${undefined}
    `('creates workflow with $description', async ({ projectId, namespaceId }) => {
      const params = {
        goal: MOCK_GOAL,
        activeThread: MOCK_ACTIVE_THREAD,
      };

      if (projectId) params.projectId = projectId;
      if (namespaceId) params.namespaceId = namespaceId;

      await ApolloUtils.createWorkflow(apolloProvider.defaultClient, params);

      const expectedCallVariables = {
        goal: MOCK_GOAL,
        workflowDefinition: DUO_WORKFLOW_CHAT_DEFINITION,
        agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
        preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
        threadId: MOCK_ACTIVE_THREAD,
        conversationType: MULTI_THREADED_CONVERSATION_TYPE,
      };

      if (projectId) expectedCallVariables.projectId = projectId;
      if (namespaceId) expectedCallVariables.namespaceId = namespaceId;

      expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith(expectedCallVariables);
      expect(parseGid).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
    });
  });

  describe('deleteWorkflow', () => {
    const mockWorkflowId = '123';

    it('successfully deletes workflow', async () => {
      deleteWorkflowMutationHandlerMock.mockResolvedValue(MOCK_DELETE_WORKFLOW_RESPONSE);

      await ApolloUtils.deleteWorkflow(apolloProvider.defaultClient, mockWorkflowId);

      expect(deleteWorkflowMutationHandlerMock).toHaveBeenCalledWith({
        input: {
          workflowId: mockWorkflowId,
        },
      });
    });
  });

  describe('fetchWorkflowEvents', () => {
    const mockWorkflowId = '456';

    it('successfully fetches workflow events', async () => {
      const mockApolloClient = {
        query: jest.fn().mockResolvedValue(MOCK_FETCH_WORKFLOW_EVENTS_RESPONSE),
      };

      const result = await ApolloUtils.fetchWorkflowEvents(mockApolloClient, mockWorkflowId);

      expect(mockApolloClient.query).toHaveBeenCalledWith({
        query: getWorkflowEventsQuery,
        variables: {
          workflowId: mockWorkflowId,
        },
        fetchPolicy: 'network-only',
      });

      expect(result).toBe(MOCK_FETCH_WORKFLOW_EVENTS_RESPONSE.data);
    });
  });
});
