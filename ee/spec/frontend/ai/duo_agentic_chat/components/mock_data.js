export const MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE = {
  data: {
    aiChatAvailableModels: {
      defaultModel: {
        name: 'Claude Sonnet 4.0 - Anthropic',
        ref: 'claude_sonnet_4_20250514',
      },
      selectableModels: [
        {
          name: 'Claude Sonnet 4.0 - Anthropic',
          ref: 'claude_sonnet_4_20250514',
        },
        {
          name: 'Claude Sonnet 3.5 - Anthropic',
          ref: 'claude_3_5_sonnet_20240620',
        },
      ],
      pinnedModel: null,
    },
  },
};

export const MOCK_AI_CHAT_AVAILABLE_MODELS_WITH_PINNED_MODEL_RESPONSE = {
  data: {
    aiChatAvailableModels: {
      ...MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE.data.aiChatAvailableModels,
      pinnedModel: {
        name: 'OpenAI GPT-5-Codex',
        ref: 'gpt_5_codex',
      },
    },
  },
};

export const MOCK_GITLAB_DEFAULT_MODEL_ITEM = {
  value: '',
  text: 'Claude Sonnet 4.0 - Anthropic',
};

export const MOCK_MODEL_LIST_ITEMS = [
  { text: 'Claude Sonnet 4.0 - Anthropic', value: '' },
  { text: 'Claude Sonnet 3.5 - Anthropic', value: 'claude_3_5_sonnet_20240620' },
];

export const MOCK_CONFIGURED_AGENTS_RESPONSE = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          id: 'Configured Item 5',
          item: {
            id: 'Agent 5',
            name: 'My Custom Agent',
            description: 'This is my custom agent',
            versions: {
              nodes: [
                {
                  id: 'AgentVersion 6',
                  released: false,
                },
                {
                  id: 'AgentVersion 5',
                  released: true,
                },
              ],
            },
          },
        },
      ],
    },
  },
};

export const DUO_CHAT_AGENT_MOCK = {
  id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
  name: 'GitLab Duo Agent',
  description: 'Duo is your general development assistant',
  referenceWithVersion: 'chat',
};

export const DUO_FOUNDATIONAL_AGENT_MOCK = {
  id: 'gid://gitlab/Ai::FoundationalChatAgent/agent-v1',
  name: 'Cool agent',
  description: 'An agent that makes things cooler',
  referenceWithVersion: 'agent/v1',
};

export const MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE = {
  data: {
    aiFoundationalChatAgents: {
      nodes: [DUO_CHAT_AGENT_MOCK, DUO_FOUNDATIONAL_AGENT_MOCK],
    },
  },
};

export const MOCK_FETCHED_FOUNDATIONAL_AGENT = {
  ...DUO_FOUNDATIONAL_AGENT_MOCK,
  text: DUO_FOUNDATIONAL_AGENT_MOCK.name,
  foundational: true,
};

export const MOCK_FLOW_AGENT_CONFIG = 'components:\n  - name: test\n    type: agent';
export const MOCK_FLOW_CONFIG_RESPONSE = {
  data: { aiCatalogAgentFlowConfig: MOCK_FLOW_AGENT_CONFIG },
};
