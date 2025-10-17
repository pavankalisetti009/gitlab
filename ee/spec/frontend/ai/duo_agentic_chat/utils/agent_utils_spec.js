import {
  validateAgentExists,
  prepareAgentSelection,
} from 'ee/ai/duo_agentic_chat/utils/agent_utils';

describe('agent_utils', () => {
  describe('validateAgentExists', () => {
    const mockCatalogAgents = [
      {
        name: 'Test Agent 1',
        versions: {
          nodes: [{ id: 'version-123' }, { id: 'version-456' }],
        },
      },
      {
        name: 'Test Agent 2',
        versions: {
          nodes: [{ id: 'version-789' }],
        },
      },
    ];

    describe('when no agent version ID is provided', () => {
      it('returns available with no error', () => {
        const result = validateAgentExists(null, mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: true,
          errorMessage: '',
        });
      });
    });

    describe('when agent version exists in catalog', () => {
      it('returns available with no error', () => {
        const result = validateAgentExists('version-123', mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: true,
          errorMessage: '',
        });
      });
    });

    describe('when agent version does not exist in catalog', () => {
      it('returns not available with error message', () => {
        const result = validateAgentExists('version-999', mockCatalogAgents);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when catalog agents is empty', () => {
      it('returns not available with error message', () => {
        const result = validateAgentExists('version-123', []);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when agent has no versions', () => {
      it('returns not available with error message', () => {
        const agentsWithoutVersions = [
          {
            name: 'Test Agent',
            versions: { nodes: [] },
          },
        ];

        const result = validateAgentExists('version-123', agentsWithoutVersions);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });

    describe('when catalogAgents is null or undefined', () => {
      it('returns not available with error message for null', () => {
        const result = validateAgentExists('version-123', null);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });

      it('returns not available with error message for undefined', () => {
        const result = validateAgentExists('version-123', undefined);

        expect(result).toEqual({
          isAvailable: false,
          errorMessage:
            'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
        });
      });
    });
  });

  describe('prepareAgentSelection', () => {
    describe('when reuseAgent is true', () => {
      it('returns null to keep current agent', () => {
        const agent = { id: 'agent-123' };

        const result = prepareAgentSelection(agent, true);

        expect(result).toBeNull();
      });
    });

    describe('when foundational agent is selected', () => {
      it('returns foundational agent state', () => {
        const agent = {
          id: 'foundational-agent-123',
          name: 'Code Generation Agent',
          foundational: true,
        };

        const result = prepareAgentSelection(agent, false);

        expect(result).toEqual({
          selectedFoundationalAgent: agent,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });

    describe('when custom catalog agent is selected', () => {
      it('returns agent data with released version', () => {
        const agent = {
          id: 'agent-123',
          versions: {
            nodes: [
              { id: 'version-1', released: false },
              { id: 'version-2', released: true },
              { id: 'version-3', released: false },
            ],
          },
        };

        const result = prepareAgentSelection(agent, false);

        expect(result).toEqual({
          aiCatalogItemVersionId: 'version-2',
          selectedFoundationalAgent: null,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });

    describe('when no agent is selected', () => {
      it('returns default agent state for undefined', () => {
        const result = prepareAgentSelection(undefined, false);
        expect(result).toEqual({
          aiCatalogItemVersionId: '',
          selectedFoundationalAgent: null,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });

      it('returns default agent state for null', () => {
        const result = prepareAgentSelection(null, false);
        expect(result).toEqual({
          aiCatalogItemVersionId: '',
          selectedFoundationalAgent: null,
          agentConfig: null,
          isChatAvailable: true,
          agentDeletedError: '',
        });
      });
    });
  });
});
