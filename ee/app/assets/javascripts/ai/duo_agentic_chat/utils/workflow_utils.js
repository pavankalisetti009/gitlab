import { CHAT_MESSAGE_TYPES, GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';

export const WorkflowUtils = {
  getLatestCheckpoint(duoWorkflowEvents) {
    if (!duoWorkflowEvents.length) {
      return null;
    }

    const sortedCheckpoints = [...duoWorkflowEvents].sort((a, b) => {
      return new Date(b.checkpoint.ts).getTime() - new Date(a.checkpoint.ts).getTime();
    });

    return sortedCheckpoints[0];
  },

  parseWorkflowData(response) {
    return this.getLatestCheckpoint(
      response.duoWorkflowEvents.nodes.map((e) => ({
        ...e,
        checkpoint: JSON.parse(e.checkpoint),
      })),
    );
  },

  transformChatMessages(uiChatLog, workflowId, lastProcessedIndex = -1) {
    const startIndex = Math.max(0, Number(lastProcessedIndex || -1)); // index is -1 on the first processing
    return uiChatLog.map((msg, i) => {
      const requestId = `${workflowId}-${i + startIndex}-${msg.message_type}`;
      const role = [CHAT_MESSAGE_TYPES.agent, CHAT_MESSAGE_TYPES.request].includes(msg.message_type)
        ? GENIE_CHAT_MODEL_ROLES.assistant
        : msg.message_type;

      return {
        ...msg,
        requestId,
        role,
        message_type: msg.message_type,
      };
    });
  },
};
