import {
  buildWebsocketUrl,
  buildStartRequest,
  processWorkflowMessage,
} from 'ee/ai/duo_agentic_chat/utils/workflow_socket_utils';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import * as websocketUtils from '~/lib/utils/websocket_utils';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';

jest.mock('~/lib/utils/websocket_utils');
jest.mock('ee/ai/duo_agentic_chat/utils/workflow_utils', () => ({
  WorkflowUtils: {
    transformChatMessages: jest.fn(),
  },
}));

describe('workflow_socket_utils', () => {
  describe('buildWebsocketUrl', () => {
    describe('when no parameters are provided', () => {
      it('builds basic URL', () => {
        const url = buildWebsocketUrl({});

        expect(url).toBe('/api/v4/ai/duo_workflows/ws');
      });
    });

    describe('when rootNamespaceId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          rootNamespaceId: 'gid://gitlab/Group/123',
        });

        expect(url).toBe('/api/v4/ai/duo_workflows/ws?root_namespace_id=123');
      });
    });

    describe('when namespaceId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          namespaceId: 'gid://gitlab/Group/456',
        });

        expect(url).toBe('/api/v4/ai/duo_workflows/ws?namespace_id=456');
      });
    });

    describe('when projectId is provided', () => {
      it('includes the parameter', () => {
        const url = buildWebsocketUrl({
          projectId: 'gid://gitlab/Project/789',
        });

        expect(url).toBe('/api/v4/ai/duo_workflows/ws?project_id=789');
      });
    });

    describe('when user model selection is enabled', () => {
      describe('when current model is not the default', () => {
        it('includes user_selected_model_identifier', () => {
          const url = buildWebsocketUrl({
            rootNamespaceId: 'gid://gitlab/Group/123',
            userModelSelectionEnabled: true,
            currentModel: { value: 'custom-model' },
            defaultModel: { value: GITLAB_DEFAULT_MODEL },
          });

          expect(url).toContain('user_selected_model_identifier=custom-model');
        });
      });

      describe('when current model is the default', () => {
        it('does not include user_selected_model_identifier', () => {
          const url = buildWebsocketUrl({
            rootNamespaceId: 'gid://gitlab/Group/123',
            userModelSelectionEnabled: true,
            currentModel: { value: GITLAB_DEFAULT_MODEL },
            defaultModel: { value: GITLAB_DEFAULT_MODEL },
          });

          expect(url).not.toContain('user_selected_model_identifier');
        });
      });
    });

    describe('when multiple parameters are provided', () => {
      it('combines all parameters', () => {
        const url = buildWebsocketUrl({
          rootNamespaceId: 'gid://gitlab/Group/123',
          namespaceId: 'gid://gitlab/Group/456',
          projectId: 'gid://gitlab/Project/789',
        });

        expect(url).toContain('root_namespace_id=123');
        expect(url).toContain('namespace_id=456');
        expect(url).toContain('project_id=789');
      });
    });
  });

  describe('buildStartRequest', () => {
    describe('when called with basic parameters', () => {
      it('builds start request with required fields', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
        });

        expect(request).toEqual({
          startRequest: {
            workflowID: '123',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            workflowMetadata: 'test metadata',
            goal: 'test goal',
            approval: {},
          },
        });
      });
    });

    describe('when workflowDefinition is not null', () => {
      it('builds start request with required fields', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          workflowDefinition: 'agent/v1',
        });

        expect(request).toEqual({
          startRequest: {
            workflowID: '123',
            clientVersion: '1.0',
            workflowDefinition: 'agent/v1',
            workflowMetadata: 'test metadata',
            goal: 'test goal',
            approval: {},
          },
        });
      });
    });

    describe('when additionalContext is provided', () => {
      it('includes additionalContext in request', () => {
        const additionalContext = [{ content: 'context data' }];
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          additionalContext,
        });

        expect(request.startRequest.additionalContext).toEqual(additionalContext);
      });
    });

    describe('when agentConfig is provided', () => {
      it('includes flowConfig and schema version', () => {
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          agentConfig: 'components:\n  - name: test\n    type: agent',
        });

        expect(request.startRequest.flowConfig).toBeDefined();
        expect(request.startRequest.flowConfigSchemaVersion).toBe('experimental');
      });
    });

    describe('when approval is provided', () => {
      it('includes approval in request', () => {
        const approval = { approved: true };
        const request = buildStartRequest({
          workflowId: '123',
          goal: 'test goal',
          metadata: 'test metadata',
          approval,
        });

        expect(request.startRequest.approval).toEqual(approval);
      });
    });
  });

  describe('processWorkflowMessage', () => {
    const mockEvent = { data: 'test' };
    const mockWorkflowId = '456';

    beforeEach(() => {
      jest.clearAllMocks();
    });

    describe('when action is null', () => {
      it('returns null', async () => {
        websocketUtils.parseMessage.mockResolvedValue(null);

        const result = await processWorkflowMessage(mockEvent, mockWorkflowId);

        expect(result).toBeNull();
      });
    });

    describe('when action has no newCheckpoint', () => {
      it('returns null', async () => {
        websocketUtils.parseMessage.mockResolvedValue({ otherData: 'value' });

        const result = await processWorkflowMessage(mockEvent, mockWorkflowId);

        expect(result).toBeNull();
      });
    });

    describe('when valid workflow message is received', () => {
      it('processes and returns transformed data', async () => {
        const mockMessages = [{ content: 'test message', role: 'assistant' }];
        const mockCheckpoint = {
          channel_values: {
            ui_chat_log: [{ message: 'raw log' }],
          },
        };

        websocketUtils.parseMessage.mockResolvedValue({
          newCheckpoint: {
            checkpoint: JSON.stringify(mockCheckpoint),
            status: 'running',
            goal: 'test goal',
          },
        });

        WorkflowUtils.transformChatMessages.mockReturnValue(mockMessages);

        const result = await processWorkflowMessage(mockEvent, mockWorkflowId);

        expect(result).toEqual({
          messages: mockMessages,
          status: 'running',
          goal: 'test goal',
        });

        expect(WorkflowUtils.transformChatMessages).toHaveBeenCalledWith(
          mockCheckpoint.channel_values.ui_chat_log,
          mockWorkflowId,
        );
      });
    });
  });
});
