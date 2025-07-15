const TYPENAME_AI_CATALOG_ITEM = 'AiCatalogItem';
const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';
const TYPENAME_AI_CATALOG_ITEM_VERSION = 'AiCatalogAgentVersion';
const TYPENAME_PROJECT = 'Project';

const mockProject = {
  id: 'gid://gitlab/Project/1',
  __typename: TYPENAME_PROJECT,
};

const mockAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  __typename: TYPENAME_AI_CATALOG_ITEM,
  ...overrides,
});

const mockAgentVersions = [
  {
    id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
    versionName: 'v1.0.0-draft',
    __typename: TYPENAME_AI_CATALOG_ITEM_VERSION,
    systemPrompt: 'The system prompt',
    userPrompt: 'The user prompt',
  },
];

export const mockBaseAgent = mockAgentFactory();

export const mockAgent = mockAgentFactory({
  project: mockProject,
  versions: {
    nodes: mockAgentVersions,
  },
});

export const mockAgents = [
  mockBaseAgent,
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
  }),
];

export const mockCatalogItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockAgents,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCatalogItemResponse = {
  data: {
    aiCatalogItem: mockAgent,
  },
};

export const mockCatalogItemNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCreateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: [],
      item: mockBaseAgent,
    },
  },
};

export const mockCreateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};
