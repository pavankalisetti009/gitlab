import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';

export const MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE = {
  data: {
    aiChatAvailableModels: {
      defaultModel: {
        name: 'Claude Sonnet 4.0',
        ref: 'claude_sonnet_4_20250514',
        modelProvider: 'Anthropic',
        modelDescription: 'Fast, cost-effective responses.',
      },
      selectableModels: [
        {
          name: 'Claude Sonnet 4.0',
          ref: 'claude_sonnet_4_20250514',
          modelProvider: 'Anthropic',
          modelDescription: 'Fast, cost-effective responses.',
        },
        {
          name: 'Claude Sonnet 3.5',
          ref: 'claude_3_5_sonnet_20240620',
          modelProvider: 'Anthropic',
          modelDescription: 'Fast, cost-effective responses.',
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
  value: GITLAB_DEFAULT_MODEL,
  text: 'Claude Sonnet 4.0 - Default',
  modelProvider: 'Anthropic',
  modelDescription: 'Fast, cost-effective responses.',
};

export const MOCK_MODEL_LIST_ITEMS = [
  {
    text: 'Claude Sonnet 4.0 - Default',
    value: GITLAB_DEFAULT_MODEL,
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
  },
  {
    text: 'Claude Sonnet 3.5',
    value: 'claude_3_5_sonnet_20240620',
    provider: 'Anthropic',
    description: 'Fast, cost-effective responses.',
  },
];

export const MOCK_CONFIGURED_AGENTS_RESPONSE = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          id: 'Configured Item 5',
          pinnedItemVersion: {
            id: 'AgentVersion 5',
          },
          item: {
            id: 'Agent 5',
            name: 'My Custom Agent',
            description: 'This is my custom agent',
          },
        },
      ],
      __typename: 'AiCatalogItemConsumerConnection',
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
