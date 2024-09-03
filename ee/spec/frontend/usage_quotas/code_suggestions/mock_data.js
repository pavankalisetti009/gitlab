import {
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
} from 'ee/usage_quotas/code_suggestions/constants';

export const noAssignedDuoProAddonData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_CODE_SUGGESTIONS,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};
export const deprecatedNoAssignedDuoProAddonData = {
  data: {
    addOnPurchase: {
      id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
      name: ADD_ON_CODE_SUGGESTIONS,
      assignedQuantity: 0,
      purchasedQuantity: 20,
      __typename: 'AddOnPurchase',
    },
  },
};

export const noAssignedDuoEnterpriseAddonData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_DUO_ENTERPRISE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};
export const deprecatedNoAssignedDuoEnterpriseAddonData = {
  data: {
    addOnPurchase: {
      id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
      name: ADD_ON_DUO_ENTERPRISE,
      assignedQuantity: 0,
      purchasedQuantity: 20,
      __typename: 'AddOnPurchase',
    },
  },
};

export const noAssignedDuoAddonsData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_CODE_SUGGESTIONS,
        assignedQuantity: 0,
        purchasedQuantity: 15,
        __typename: 'AddOnPurchase',
      },
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/4',
        name: ADD_ON_DUO_ENTERPRISE,
        assignedQuantity: 0,
        purchasedQuantity: 20,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};

export const noPurchasedAddonData = {
  data: {
    addOnPurchases: [],
  },
};
export const deprecatedNoPurchasedAddonData = {
  data: {
    addOnPurchase: null,
  },
};

export const purchasedAddonFuzzyData = {
  data: {
    addOnPurchases: [
      {
        id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        name: ADD_ON_CODE_SUGGESTIONS,
        assignedQuantity: 0,
        purchasedQuantity: null,
        __typename: 'AddOnPurchase',
      },
    ],
  },
};
export const deprecatedPurchasedAddonFuzzyData = {
  data: {
    addOnPurchase: {
      id: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
      name: ADD_ON_CODE_SUGGESTIONS,
      assignedQuantity: 0,
      purchasedQuantity: null,
      __typename: 'AddOnPurchase',
    },
  },
};

export const mockSMUserWithAddOnAssignment = {
  id: 'gid://gitlab/User/1',
  username: 'userone',
  name: 'User One',
  publicEmail: null,
  avatarUrl: 'path/to/img_userone',
  webUrl: 'path/to/userone',
  lastActivityOn: '2023-08-25',
  maxRole: null,
  addOnAssignments: {
    nodes: [{ addOnPurchase: { name: ADD_ON_CODE_SUGGESTIONS } }],
    __typename: 'UserAddOnAssignmentConnection',
  },
  __typename: 'AddOnUser',
};

export const mockSMUserWithNoAddOnAssignment = {
  id: 'gid://gitlab/User/2',
  username: 'usertwo',
  name: 'User Two',
  publicEmail: null,
  avatarUrl: 'path/to/img_usertwo',
  webUrl: 'path/to/usertwo',
  lastActivityOn: '2023-08-22',
  maxRole: null,
  addOnAssignments: { nodes: [], __typename: 'UserAddOnAssignmentConnection' },
  __typename: 'AddOnUser',
};

export const mockAnotherSMUserWithNoAddOnAssignment = {
  id: 'gid://gitlab/User/3',
  username: 'userthree',
  name: 'User Three',
  publicEmail: null,
  avatarUrl: 'path/to/img_userthree',
  webUrl: 'path/to/userthree',
  lastActivityOn: '2023-03-19',
  maxRole: null,
  addOnAssignments: { nodes: [], __typename: 'UserAddOnAssignmentConnection' },
  __typename: 'AddOnUser',
};

export const mockUserWithAddOnAssignment = {
  ...mockSMUserWithAddOnAssignment,
  membershipType: null,
};

export const mockUserWithNoAddOnAssignment = {
  ...mockSMUserWithNoAddOnAssignment,
  membershipType: null,
};

export const mockAnotherUserWithNoAddOnAssignment = {
  ...mockAnotherSMUserWithNoAddOnAssignment,
  membershipType: null,
};

export const eligibleUsers = [
  mockUserWithAddOnAssignment,
  mockUserWithNoAddOnAssignment,
  mockAnotherUserWithNoAddOnAssignment,
];
export const eligibleSMUsers = [mockSMUserWithAddOnAssignment, mockSMUserWithNoAddOnAssignment];
export const eligibleUsersWithMaxRole = eligibleUsers.map((user) => ({
  ...user,
  maxRole: 'developer',
}));

const pageInfo = {
  startCursor: 'start-cursor',
  endCursor: 'end-cursor',
  __typename: 'PageInfo',
};

export const pageInfoWithNoPages = {
  hasNextPage: false,
  hasPreviousPage: false,
  ...pageInfo,
};

export const pageInfoWithMorePages = {
  hasNextPage: true,
  hasPreviousPage: true,
  ...pageInfo,
};

export const mockAddOnEligibleUsers = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers,
        pageInfo: pageInfoWithNoPages,
        __typename: 'AddOnUserConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const mockPaginatedAddOnEligibleUsers = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers,
        pageInfo: pageInfoWithMorePages,
      },
    },
  },
};

export const mockPaginatedAddOnEligibleUsersWithMembershipType = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      addOnEligibleUsers: {
        nodes: eligibleUsers.map((user) => ({ ...user, membershipType: 'group_invite' })),
        pageInfo: pageInfoWithMorePages,
      },
    },
  },
};

export const mockNoGroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/95',
      name: 'Code Suggestions Group',
      fullName: 'Code Suggestions Group',
      fullPath: 'code-suggestions-group',
      __typename: 'Group',
      descendantGroups: {
        nodes: [],
        pageInfo: {},
        __typename: 'GroupConnection',
      },
    },
  },
};

export const mockGroups = {
  data: {
    group: {
      id: 'gid://gitlab/Group/95',
      name: 'Code Suggestions Group',
      fullName: 'Code Suggestions Group',
      fullPath: 'code-suggestions-group',
      __typename: 'Group',
      descendantGroups: {
        nodes: [
          {
            id: 'gid://gitlab/Group/99',
            name: 'Code Suggestions Subgroup',
            fullName: 'Code Suggestions Group / Code Suggestions Subgroup',
            fullPath: 'code-suggestions-group/code-suggestions-subgroup',
            __typename: 'Group',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          __typename: 'PageInfo',
        },
        __typename: 'GroupConnection',
      },
    },
  },
};

export const mockNoProjects = {
  data: {
    group: {
      projects: {
        nodes: [],
        __typename: 'ProjectConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockProjects = {
  data: {
    group: {
      id: 'gid://gitlab/Group/13',
      projects: {
        nodes: [
          {
            id: 'gid://gitlab/Project/20',
            name: 'A Project',
            __typename: 'Project',
          },
          {
            id: 'gid://gitlab/Project/19',
            name: 'Another Project',
            __typename: 'Project',
          },
        ],
        __typename: 'ProjectConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockHandRaiseLeadData = {
  glmContent: 'code-suggestions',
  productInteraction: 'Requested Contact-Duo Pro Add-On',
  buttonAttributes: {},
  ctaTracking: {},
};

export const MOCK_NETWORK_PROBES = {
  success: [
    {
      name: 'host_probe',
      success: true,
      message: 'customers.staging.gitlab.com reachable.',
    },
    {
      name: 'host_probe',
      success: true,
      message: 'cloud.gitlab.com reachable.',
    },
  ],
  error: [
    {
      name: 'host_probe',
      success: false,
      message: 'customers.staging.gitlab.com is not reachable.',
    },
    {
      name: 'host_probe',
      success: false,
      message: 'cloud.gitlab.com is not reachable.',
    },
  ],
};

export const MOCK_SYNCHRONIZATION_PROBES = {
  success: [
    {
      name: 'access_probe',
      success: true,
      message: 'Subscription can be synchronized.',
    },
    {
      name: 'license_probe',
      success: true,
      message: 'Subscription synchronized successfully.',
    },
  ],
  error: [
    {
      name: 'access_probe',
      success: false,
      message: 'Subscription has not yet been synchronized. Synchronize your subscription.',
    },
    {
      name: 'license_probe',
      success: false,
      message:
        'Subscription for this instance cannot be synchronized. Contact GitLab customer support to upgrade your license.',
    },
  ],
};

export const MOCK_SYSTEM_EXCHANGE_PROBES = {
  success: [
    {
      name: 'end_to_end_probe',
      success: true,
      message: 'Authentication with GitLab Cloud services succeeded.',
    },
  ],
  error: [
    {
      name: 'end_to_end_probe',
      success: false,
      message: 'Authentication with GitLab Cloud services failed: Access token is missing',
    },
  ],
};
