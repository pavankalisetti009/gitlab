const TYPENAME_AI_CATALOG_ITEM = 'AiCatalogItem';
const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';

export const mockAgent = {
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  __typename: TYPENAME_AI_CATALOG_ITEM,
};

export const mockAgents = [
  mockAgent,
  {
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    itemType: 'AGENT',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    __typename: TYPENAME_AI_CATALOG_ITEM,
  },
  {
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    itemType: 'AGENT',
    createdAt: '2024-02-10T14:20:00Z',
    description: 'Another AI assistant',
    __typename: TYPENAME_AI_CATALOG_ITEM,
  },
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
