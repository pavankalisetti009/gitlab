import {
  TYPENAME_AI_CATALOG_ITEM_CONNECTION,
  TYPENAME_PROJECT,
  mockAgentsWithConfig,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';

export const mockProjectAgentsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: mockAgentsWithConfig,
        pageInfo: mockPageInfo,
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockProjectItemsEmptyResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiCatalogItems: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
        __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};
