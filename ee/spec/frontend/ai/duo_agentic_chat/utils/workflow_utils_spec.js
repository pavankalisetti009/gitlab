import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import {
  MOCK_ASSISTANT_MESSAGES,
  MOCK_SINGLE_GENERIC_MESSAGE,
  MOCK_MULTIPLE_USER_MESSAGES,
  MOCK_USER_MESSAGE_WITH_PROPERTIES,
  MOCK_WORKFLOW_EVENTS_MULTIPLE,
  MOCK_SINGLE_WORKFLOW_EVENT,
  MOCK_PARSE_WORKFLOW_RESPONSE,
  MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE,
  MOCK_PARSE_WORKFLOW_PRESERVE_PROPERTIES_RESPONSE,
} from './mock_data';

describe('WorkflowUtils', () => {
  describe('getLatestCheckpoint', () => {
    it('returns null when duoWorkflowEvents is empty', () => {
      const result = WorkflowUtils.getLatestCheckpoint([]);

      expect(result).toBeNull();
    });

    it('returns the most recent checkpoint when multiple events exist', () => {
      const result = WorkflowUtils.getLatestCheckpoint(MOCK_WORKFLOW_EVENTS_MULTIPLE);

      expect(result.metadata).toBe('second');
      expect(result.workflowStatus).toBe('INPUT_REQUIRED');
      expect(result.workflowGoal).toBe('Test goal 2');
      expect(result.checkpoint.ts).toBe('2025-07-25T14:30:43.905127+00:00');
    });

    it('returns single checkpoint when only one event exists', () => {
      const result = WorkflowUtils.getLatestCheckpoint(MOCK_SINGLE_WORKFLOW_EVENT);

      expect(result.metadata).toBe('single event');
      expect(result.errors).toEqual(['some error']);
      expect(result.workflowStatus).toBe('FAILED');
      expect(result.workflowGoal).toBe('Single goal');
    });
  });

  describe('parseWorkflowData', () => {
    beforeEach(() => {
      jest.spyOn(WorkflowUtils, 'getLatestCheckpoint');
    });

    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('calls getLatestCheckpoint with parsed checkpoint data', () => {
      WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_RESPONSE);

      expect(WorkflowUtils.getLatestCheckpoint).toHaveBeenCalledWith([
        {
          metadata: 'first',
          checkpoint: { ts: '2025-07-25T14:30:10.117131+00:00', data: 'test1' },
        },
        {
          metadata: 'second',
          checkpoint: { ts: '2025-07-25T14:30:43.905127+00:00', data: 'test2' },
        },
      ]);
    });

    it('calls getLatestCheckpoint with empty array when no nodes', () => {
      WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_EMPTY_RESPONSE);

      expect(WorkflowUtils.getLatestCheckpoint).toHaveBeenCalledWith([]);
    });

    it('preserves all node properties while parsing checkpoint', () => {
      WorkflowUtils.parseWorkflowData(MOCK_PARSE_WORKFLOW_PRESERVE_PROPERTIES_RESPONSE);

      expect(WorkflowUtils.getLatestCheckpoint).toHaveBeenCalledWith([
        {
          metadata: 'test',
          workflowStatus: 'RUNNING',
          customProperty: 'preserved',
          checkpoint: { ts: '2025-07-25T14:30:10.117131+00:00' },
        },
      ]);
    });
  });

  describe('transformChatMessages', () => {
    it('maps agent and request message types to assistant role', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_ASSISTANT_MESSAGES);

      expect(result[0].role).toBe(GENIE_CHAT_MODEL_ROLES.assistant);
      expect(result[1].role).toBe(GENIE_CHAT_MODEL_ROLES.assistant);
    });

    it('preserves original message_type for non-agent/request messages', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_SINGLE_GENERIC_MESSAGE);
      expect(result[0].role).toBe('generic');
    });

    it('preserves all original message properties', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_USER_MESSAGE_WITH_PROPERTIES);

      expect(result[0]).toEqual({
        ...MOCK_USER_MESSAGE_WITH_PROPERTIES[0],
        requestId: 'msg-7',
        role: 'user',
      });
    });

    it('sets requestId to message_id for each message', () => {
      const result = WorkflowUtils.transformChatMessages(MOCK_MULTIPLE_USER_MESSAGES);

      expect(result[0].requestId).toBe('msg-4');
      expect(result[1].requestId).toBe('msg-5');
      expect(result[2].requestId).toBe('msg-6');
    });
  });
});
