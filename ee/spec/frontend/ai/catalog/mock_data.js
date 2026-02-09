export const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER = 'AiCatalogItemConsumer';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE = 'AiCatalogItemConsumerUpdate';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE = 'AiCatalogItemConsumerDeletePayload';
const TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION = 'AiCatalogItemConsumerConnection';
const TYPENAME_AI_CATALOG_AGENT = 'AiCatalogAgent';
const TYPENAME_AI_CATALOG_AGENT_CREATE = 'AiCatalogAgentCreatePayload';
const TYPENAME_AI_CATALOG_AGENT_UPDATE = 'AiCatalogAgentUpdatePayload';
const TYPENAME_AI_CATALOG_AGENT_DELETE = 'AiCatalogAgentDeletePayload';
const TYPENAME_AI_CATALOG_AGENT_VERSION = 'AiCatalogAgentVersion';
const TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION = 'AiCatalogBuiltInToolConnection';
const TYPENAME_AI_CATALOG_FLOW = 'AiCatalogFlow';
const TYPENAME_AI_CATALOG_FLOW_VERSION = 'AiCatalogFlowVersion';
const TYPENAME_AI_CATALOG_FLOW_CREATE = 'AiCatalogFlowCreatePayload';
const TYPENAME_AI_CATALOG_FLOW_UPDATE = 'AiCatalogFlowUpdatePayload';
const TYPENAME_AI_CATALOG_FLOW_DELETE = 'AiCatalogFlowDeletePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_CREATE = 'AiCatalogThirdPartyFlowCreatePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_UPDATE = 'AiCatalogThirdPartyFlowCreatePayload';
const TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION = 'AiCatalogThirdPartyFlowVersion';
const TYPENAME_AI_FLOW_TRIGGER = 'AiFlowTriggerType';
const TYPENAME_GROUP = 'Group';
const TYPENAME_GROUP_PERMISSIONS = 'GroupPermissions';
export const TYPENAME_PROJECT = 'Project';
const TYPENAME_PROJECT_PERMISSIONS = 'ProjectPermissions';
const TYPENAME_PROJECTS_CONNECTION = 'ProjectsConnection';
const TYPENAME_AI_CATALOG_ITEM_REPORT = 'AiCatalogItemReportPayload';
const TYPENAME_USER = 'User';

const mockVersionFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
  updatedAt: '2025-08-21T14:30:00Z',
  ...overrides,
});

export const mockBaseVersion = mockVersionFactory();

const mockProjectFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Project/1',
  __typename: TYPENAME_PROJECT,
  ...overrides,
});

const mockUserPermissionsFactory = (overrides = {}) => ({
  adminAiCatalogItem: true,
  reportAiCatalogItem: true,
  forceHardDeleteAiCatalogItem: true,
  ...overrides,
});

const mockItemConsumerUserPermissionsFactory = (overrides = {}) => ({
  adminAiCatalogItemConsumer: true,
  ...overrides,
});

const mockUserPermissions = mockUserPermissionsFactory();
const mockItemConsumerUserPermissions = mockItemConsumerUserPermissionsFactory();

export const mockProjectWithNamespace = mockProjectFactory({
  nameWithNamespace: 'Group / Project 1',
});

export const mockProjectWithGroup = mockProjectFactory({
  nameWithNamespace: 'Group / Project 1',
  webUrl: 'https://gitlab.com/gitlab-org/test-project',
  rootGroup: {
    id: 'gid://gitlab/Group/1',
    fullName: 'Group 1',
    __typename: TYPENAME_GROUP,
  },
});

export const mockPageInfo = {
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjUxIn0',
  endCursor: 'eyJpZCI6IjM1In0',
  __typename: 'PageInfo',
};

export const mockProjects = [
  mockProjectFactory({
    id: 'gid://gitlab/Project/1',
    name: 'Project 1',
    nameWithNamespace: 'Group / Project 1',
  }),
  mockProjectFactory({
    id: 'gid://gitlab/Project/2',
    name: 'Project 2',
    nameWithNamespace: 'Group / Project 2',
  }),
];

export const mockProjectsResponse = {
  data: {
    projects: {
      nodes: mockProjects,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockEmptyProjectsResponse = {
  data: {
    projects: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_PROJECTS_CONNECTION,
    },
  },
};

export const mockToolsIds = [
  'gid://gitlab/Ai::Catalog::BuiltInTool/1',
  'gid://gitlab/Ai::Catalog::BuiltInTool/2',
  'gid://gitlab/Ai::Catalog::BuiltInTool/3',
];

export const mockAiCatalogBuiltInToolsNodes = [
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/3`,
    title: 'Ci Linter',
    description: 'Ci Linter Tool description',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/2`,
    title: 'Gitlab Blob Search',
    description: 'Gitlab Blob Search Tool description',
  },
  {
    id: `gid://gitlab/Ai::Catalog::BuiltInTool/1`,
    title: 'Run Git Command',
    description: 'Run Git Command Tool description',
  },
];

export const mockToolsQueryResponse = {
  data: {
    aiCatalogBuiltInTools: {
      nodes: mockAiCatalogBuiltInToolsNodes,
      __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
    },
  },
};

/* AGENTS */

export const mockAgentVersions = {
  nodes: [
    {
      ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/20' }),
      systemPrompt: 'sys',
      tools: { nodes: [], __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION },
      versionName: '1.0.0',
      humanVersionName: 'v1.0.0',
      __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
    },
  ],
  __typename: 'AiCatalogItemVersionConnection',
};

export const mockItemTypeConfig = {
  showRoute: 'show',
  visibilityTooltip: {
    Public: 'This item is publicly available.',
    Private: 'This item is private.',
  },
};

const mockAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  softDeleted: false,
  public: true,
  updatedAt: '2024-08-21T14:30:00Z',
  latestVersion: mockBaseVersion,
  userPermissions: mockUserPermissions,
  __typename: TYPENAME_AI_CATALOG_AGENT,
  foundational: false,
  ...overrides,
});

export const mockAgentVersion = {
  ...mockBaseVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt',
  tools: {
    nodes: [],
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
};

export const mockAgentPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/2' }),
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt pinned',
  tools: {
    nodes: mockAiCatalogBuiltInToolsNodes,
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
};

export const mockAgentGroupPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/3' }),
  humanVersionName: 'v0.8.0',
  versionName: '0.8.0',
  __typename: TYPENAME_AI_CATALOG_AGENT_VERSION,
  systemPrompt: 'The system prompt group pinned version',
  tools: {
    nodes: mockAiCatalogBuiltInToolsNodes,
    __typename: TYPENAME_AI_CATALOG_AGENT_TOOLS_CONNECTION,
  },
};

export const mockBaseAgent = mockAgentFactory();

export const mockAgent = mockAgentFactory({
  project: mockProjectWithGroup,
  latestVersion: mockAgentVersion,
});

export const mockAgents = [
  mockAgentFactory({
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    versions: mockAgentVersions,
    public: false,
  }),
];

export const mockAgentsWithConfig = [
  mockAgentFactory({
    versions: mockAgentVersions,
    project: mockProjectWithNamespace,
    latestVersion: mockVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
      humanVersionName: 'v1.1.0',
    }),
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
      enabled: true,
      pinnedItemVersion: {
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/2',
        humanVersionName: 'v1.0.0',
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    versions: mockAgentVersions,
    project: mockProjectWithNamespace,
    latestVersion: mockVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/3',
      humanVersionName: 'v1.0.0',
    }),
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/2',
      enabled: true,
      pinnedItemVersion: {
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/4',
        humanVersionName: 'v1.0.0',
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
    versions: mockAgentVersions,
    project: mockProjectWithNamespace,
    latestVersion: mockVersionFactory({
      id: 'gid://gitlab/Ai::Catalog::ItemVersion/5',
      humanVersionName: 'v1.0.0',
    }),
    public: false,
    configurationForProject: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
      enabled: true,
      pinnedItemVersion: {
        id: 'gid://gitlab/Ai::Catalog::ItemVersion/6',
        humanVersionName: 'v1.0.0',
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
    configurationForGroup: {
      id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
      enabled: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
    },
  }),
];

export const mockCatalogItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockAgents,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCatalogEmptyItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: [],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockAgentConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
  enabled: true,
  pinnedItemVersion: mockAgentPinnedVersion,
  flowTrigger: null,
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockItemConfigurationForGroup = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/4',
  enabled: true,
  serviceAccount: null,
  pinnedItemVersion: mockAgentGroupPinnedVersion,
  group: {
    id: 'gid://gitlab/Group/1',
    duoSettingsPath: '/groups/mock-group/-/settings/gitlab_duo/configuration',
  },
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockAiCatalogAgentResponse = {
  data: {
    aiCatalogItem: {
      ...mockAgent,
      configurationForProject: mockAgentConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    },
  },
};

export const mockVersionProp = {
  isUpdateAvailable: false,
  activeVersionKey: 'latestVersion',
};

export const mockAiCatalogAgentNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogAgentDeleteResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCatalogAgentDeleteErrorResponse = {
  data: {
    aiCatalogAgentDelete: {
      errors: ['You do not have permission to delete this AI agent.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_AGENT_DELETE,
    },
  },
};

export const mockCreateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: [],
      item: mockBaseAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_CREATE,
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

export const mockUpdatedAgentVersion = {
  ...mockAgentVersion,
  updatedAt: '2025-08-22T14:30:00Z',
};

export const mockUpdateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: {
        ...mockAgent,
        latestVersion: mockUpdatedAgentVersion,
      },
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentNoChangeMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: mockAgent,
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentMetadataOnlyMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: [],
      item: {
        ...mockAgent,
        updatedAt: '2025-08-22T14:30:00Z',
      },
      __typename: TYPENAME_AI_CATALOG_AGENT_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdateAiCatalogItemConsumerSuccess = {
  data: {
    aiCatalogItemConsumerUpdate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/3',
        pinnedVersionPrefix: '2.0.0',
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogItemConsumerError = {
  data: {
    aiCatalogItemConsumerUpdate: {
      errors: ['Some error'],
      itemConsumer: null,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_UPDATE,
    },
  },
};

/* FLOWS */

export const mockFlowVersion = {
  ...mockBaseVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  definition: 'version: "v1"',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

export const mockFlowPinnedVersion = {
  ...mockFlowVersion,
  id: 'gid://gitlab/Ai::Catalog::ItemVersion/25',
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  definition: 'version: "v0.9.0" pinned',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

export const mockFlowGroupPinnedVersion = {
  ...mockVersionFactory({ id: 'gid://gitlab/Ai::Catalog::ItemVersion/26' }),
  humanVersionName: 'v0.8.0',
  versionName: '0.8.0',
  definition: 'version: "v0.8.0" group pinned',
  __typename: TYPENAME_AI_CATALOG_FLOW_VERSION,
};

const mockFlowFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/4',
  name: 'Test AI Flow 1',
  itemType: 'FLOW',
  description: 'A helpful AI flow for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  public: true,
  updatedAt: '2024-08-21T14:30:00Z',
  softDeleted: false,
  foundational: false,
  latestVersion: mockBaseVersion,
  userPermissions: mockUserPermissions,
  __typename: TYPENAME_AI_CATALOG_FLOW,
  ...overrides,
});

export const mockFlow = mockFlowFactory({
  project: mockProjectWithGroup,
  latestVersion: mockFlowVersion,
});

export const mockBaseFlow = mockFlowFactory();

export const mockFlows = [
  mockFlowFactory({
    project: mockProjectWithNamespace,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/5',
    name: 'Test AI Flow 2',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/6',
    name: 'Test AI Flow 3',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
  }),
];

export const mockBaseConfigs = {
  configurationForProject: {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
    enabled: true,
    __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
  },
  configurationForGroup: {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/14',
    enabled: true,
    __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
  },
};

export const mockFlowsWithConfigs = [
  mockFlowFactory({
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/5',
    name: 'Test AI Flow 2',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
  mockFlowFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/6',
    name: 'Test AI Flow 3',
    description: 'Another AI flow',
    createdAt: '2024-02-10T14:20:00Z',
    project: mockProjectWithNamespace,
    ...mockBaseConfigs,
  }),
];

export const mockServiceAccount = {
  id: 'gid://gitlab/User/100',
  name: 'Fix pipeline/v1',
  createdAt: '2024-01-10T14:20:00Z',
  username: 'ai-fix-pipeline-v1-group-1',
  webPath: '/ai-fix-pipeline-v1-group-1',
  avatarUrl: 'https://example.com/avatar.png',
  __typename: TYPENAME_USER,
};

export const mockFlowTrigger = {
  id: 'gid://gitlab/Ai::FlowTrigger/73',
  eventTypes: [0],
  user: mockServiceAccount,
  __typename: TYPENAME_AI_FLOW_TRIGGER,
};

export const mockFlowConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
  enabled: true,
  flowTrigger: mockFlowTrigger,
  pinnedItemVersion: mockFlowPinnedVersion,
  userPermissions: mockItemConsumerUserPermissions,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockFlowConfigurationForGroup = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/4',
  enabled: true,
  pinnedItemVersion: mockFlowGroupPinnedVersion,
  userPermissions: mockItemConsumerUserPermissions,
  serviceAccount: mockServiceAccount,
  group: {
    id: 'gid://gitlab/Group/1',
    duoSettingsPath: '/groups/mock-group/-/settings/gitlab_duo/configuration',
  },
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockCatalogFlowsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockFlows,
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCreateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_CREATE,
    },
  },
};

export const mockCreateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockUpdatedFlowVersion = {
  ...mockFlowVersion,
  updatedAt: '2025-08-22T14:30:00Z',
};

export const mockUpdateAiCatalogFlowSuccessMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: {
        ...mockFlow,
        latestVersion: mockUpdatedFlowVersion,
      },
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowNoChangeMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: mockFlow,
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowMetadataOnlyMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: [],
      item: {
        ...mockFlow,
        updatedAt: '2025-08-22T14:30:00Z',
      },
      __typename: TYPENAME_AI_CATALOG_FLOW_UPDATE,
    },
  },
};

export const mockUpdateAiCatalogFlowErrorMutation = {
  data: {
    aiCatalogFlowUpdate: {
      errors: ['Some error'],
      item: null,
    },
  },
};

export const mockAiCatalogFlowResponse = {
  data: {
    aiCatalogItem: {
      ...mockFlow,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockFlowConfigurationForGroup,
    },
  },
};

export const mockAiCatalogFlowNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCatalogFlowDeleteResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

export const mockCatalogFlowDeleteErrorResponse = {
  data: {
    aiCatalogFlowDelete: {
      errors: ['You do not have permission to delete this AI flow.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_FLOW_DELETE,
    },
  },
};

/* THIRD-PARTY FLOWS */

export const mockThirdPartyFlowVersion = {
  ...mockBaseVersion,
  humanVersionName: 'v1.0.0-draft',
  versionName: '1.0.0',
  definition: '---\\nimage: node:22\\ncommands:\\n- ls\\ninjectGatewayToken: true\\n',
  __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION,
};

export const mockThirdPartyFlowPinnedVersion = {
  ...mockBaseVersion,
  humanVersionName: 'v0.9.0',
  versionName: '0.9.0',
  definition: '---\\nimage: node:22\\ncommands:\\n- ls\\ninjectGatewayToken: true\\npinned',
  __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_VERSION,
};

export const mockThirdPartyFlowConfigurationForProject = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/12',
  flowTrigger: mockFlowTrigger,
  pinnedItemVersion: mockThirdPartyFlowPinnedVersion,
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

const mockThirdPartyFlowFactory = (overrides = {}) => ({
  ...mockFlowFactory(overrides),
  itemType: 'THIRD_PARTY_FLOW',
});

export const mockThirdPartyFlow = mockThirdPartyFlowFactory({
  project: mockProjectWithNamespace,
  latestVersion: mockThirdPartyFlowVersion,
});

export const mockCreateAiCatalogThirdPartyFlowSuccessMutation = {
  data: {
    aiCatalogThirdPartyFlowCreate: {
      errors: [],
      item: mockThirdPartyFlow,
      __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_CREATE,
    },
  },
};

export const mockUpdateAiCatalogThirdPartyFlowSuccessMutation = {
  data: {
    aiCatalogThirdPartyFlowUpdate: {
      errors: [],
      item: mockThirdPartyFlow,
      __typename: TYPENAME_AI_CATALOG_THIRD_PARTY_FLOW_UPDATE,
    },
  },
};

/* ITEM CONSUMERS */

export const mockBaseItemConsumer = {
  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
  __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER,
};

export const mockConfiguredAgentsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          ...mockBaseItemConsumer,
          item: mockBaseAgent,
        },
      ],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockAgentItemConsumer = {
  ...mockBaseItemConsumer,
  item: mockBaseAgent,
};

export const mockFlowItemConsumer = {
  ...mockBaseItemConsumer,
  item: mockBaseFlow,
};

export const mockThirdPartyFlowItemConsumer = {
  ...mockBaseItemConsumer,
  item: mockThirdPartyFlow,
};

export const mockConfiguredFlowsResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [
        {
          ...mockBaseItemConsumer,
          item: mockBaseFlow,
        },
      ],
      pageInfo: mockPageInfo,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockConfiguredItemsEmptyResponse = {
  data: {
    aiCatalogConfiguredItems: {
      nodes: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_CONNECTION,
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessProjectResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        project: {
          id: 'gid://gitlab/Project/1',
          name: 'Test',
        },
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Test',
          webUrl: 'https://gitlab.com/groups/group-1',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateSuccessGroupResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: [],
      itemConsumer: {
        id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        project: null,
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'Test',
          webUrl: 'https://gitlab.com/groups/group-1',
        },
      },
    },
  },
};

export const mockAiCatalogItemConsumerCreateErrorResponse = {
  data: {
    aiCatalogItemConsumerCreate: {
      errors: ['Item already configured.'],
      itemConsumer: null,
    },
  },
};

export const mockAiCatalogItemConsumerDeleteResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: [],
      success: true,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockAiCatalogItemConsumerDeleteErrorResponse = {
  data: {
    aiCatalogItemConsumerDelete: {
      errors: ['You do not have permission to disable this item.'],
      success: false,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONSUMER_DELETE,
    },
  },
};

export const mockGroupUserPermissionsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/2000',
      userPermissions: {
        adminAiCatalogItemConsumer: true,
        __typename: TYPENAME_GROUP_PERMISSIONS,
      },
      __typename: TYPENAME_GROUP,
    },
  },
};

export const mockProjectUserPermissionsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1000000',
      userPermissions: {
        ...mockUserPermissions,
        adminAiCatalogItemConsumer: true,
        __typename: TYPENAME_PROJECT_PERMISSIONS,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockProjectUserPermissionsNotAdminResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1000000',
      userPermissions: {
        ...mockUserPermissions,
        adminAiCatalogItemConsumer: false,
        __typename: TYPENAME_PROJECT_PERMISSIONS,
      },
      __typename: TYPENAME_PROJECT,
    },
  },
};

export const mockReportAiCatalogItemSuccessMutation = {
  data: {
    aiCatalogItemReport: {
      errors: [],
      __typename: TYPENAME_AI_CATALOG_ITEM_REPORT,
    },
  },
};

export const mockReportAiCatalogItemErrorMutation = {
  data: {
    aiCatalogItemReport: {
      errors: [
        "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
      ],
      __typename: TYPENAME_AI_CATALOG_ITEM_REPORT,
    },
  },
};

/* SERVICE ACCOUNT PROJECT MEMBERSHIPS */
const accessLevels = ['Guest', 'Developer', 'Maintainer', 'Owner'];

const createProjectMemberships = (startAt = 0) =>
  Array.from({ length: 20 }, (_, i) => {
    const id = startAt + i + 1;
    return {
      accessLevel: {
        humanAccess: accessLevels[Math.floor(Math.random() * accessLevels.length)],
      },
      createdAt: new Date(
        2024,
        Math.floor(Math.random() * 12),
        Math.floor(Math.random() * 28) + 1,
      ).toISOString(),
      id: `gid://gitlab/ProjectMember/${id}`,
      project: {
        id: `gid://gitlab/Project/${id}`,
        nameWithNamespace: `Group / Project ${id}`,
        webUrl: `https://gitlab.com/project-${id}`,
      },
    };
  });

export const mockServiceAccountProjectMembershipsResponse = {
  data: {
    user: {
      id: 'gid://gitlab/User/100',
      projectMemberships: {
        nodes: createProjectMemberships(),
        pageInfo: mockPageInfo,
      },
    },
  },
};
