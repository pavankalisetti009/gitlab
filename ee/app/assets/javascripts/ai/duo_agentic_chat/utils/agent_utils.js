import { s__ } from '~/locale';

export function validateAgentExists(aiCatalogItemVersionId, catalogAgents) {
  // No specific agent selected - using default agent, which is always available
  if (!aiCatalogItemVersionId) {
    return {
      isAvailable: true,
      errorMessage: '',
    };
  }

  // Check if the agent version exists in the catalog
  const agentExists = catalogAgents?.some(
    (agent) => agent.pinnedItemVersionId === aiCatalogItemVersionId,
  );

  if (!agentExists) {
    return {
      isAvailable: false,
      errorMessage: s__(
        'DuoAgenticChat|The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      ),
    };
  }

  return {
    isAvailable: true,
    errorMessage: '',
  };
}

export function prepareAgentSelection(agent, reuseAgent) {
  // Keep current agent when reusing
  if (reuseAgent) {
    return null;
  }

  const newParams = {
    aiCatalogItemVersionId: '',
    selectedFoundationalAgent: null,
    isChatAvailable: true,
    agentDeletedError: '',
  };

  // Select foundational agent
  if (agent?.foundational) {
    return {
      ...newParams,
      agentConfig: null,
      selectedFoundationalAgent: agent,
    };
  }

  // Select custom catalog agent
  if (agent?.id) {
    if (!agent.pinnedItemVersionId) {
      return {
        ...newParams,
        agentConfig: null,
      };
    }
    return {
      ...newParams,
      aiCatalogItemVersionId: agent.pinnedItemVersionId,
    };
  }

  // Reset to default agent
  return {
    ...newParams,
    agentConfig: null,
  };
}
