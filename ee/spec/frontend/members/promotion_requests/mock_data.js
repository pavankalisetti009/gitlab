import { CONTEXT_TYPE } from '~/members/constants';

export const pagination = {
  totalItems: 1,
};

export const groupDefaultProvide = {
  canManageMembers: true,
  context: CONTEXT_TYPE.GROUP,
  group: {
    name: 'gitlab',
    path: 'gitlab-org',
  },
  project: {
    path: null,
  },
};

export const projectDefaultProvide = {
  canManageMembers: true,
  context: CONTEXT_TYPE.PROJECT,
  group: {
    name: 'gitlab',
    path: 'gitlab-org',
  },
  project: {
    path: 'gitlab-org/gitlab-test',
  },
};

const pendingMemberApprovalsMockData = {
  count: 2,
  nodes: [
    {
      user: {
        id: 'gid://gitlab/User/49',
        name: 'Liberty Bartell',
        username: 'reported_user_3',
        avatarUrl:
          'https://www.gravatar.com/avatar/7df6adb62d7df6d8d27593fe4e308a8485293007d44f56aba1be402f9f9a859a?s=80\u0026d=identicon',
        webUrl: 'http://localhost:3000/reported_user_3',
        email: null,
        lastActivityOn: null,
        __typename: 'UserCore',
      },
      member: {
        id: 'gid://gitlab/GroupMember/97',
        accessLevel: {
          stringValue: 'GUEST',
          __typename: 'AccessLevel',
        },
        __typename: 'GroupMember',
      },
      requestedBy: {
        id: 'gid://gitlab/User/19',
        username: 'christal',
        webUrl: 'http://localhost:3000/christal',
        name: 'Kassandra Lebsack',
        __typename: 'UserCore',
      },
      newAccessLevel: {
        stringValue: 'DEVELOPER',
        __typename: 'AccessLevel',
      },
      oldAccessLevel: {
        stringValue: 'GUEST',
        __typename: 'AccessLevel',
      },
      status: 'pending',
      createdAt: '2024-07-29T11:18:52Z',
      __typename: 'MemberApproval',
    },
    {
      user: {
        id: 'gid://gitlab/User/21',
        name: 'Laronda Simonis',
        username: 'hyon.veum',
        avatarUrl:
          'https://www.gravatar.com/avatar/5bd500957738daa73818727aabceff7eb80a91b731d8d80f20fb55bd23f57f80?s=80\u0026d=identicon',
        webUrl: 'http://localhost:3000/hyon.veum',
        email: null,
        lastActivityOn: null,
        __typename: 'UserCore',
      },
      member: {
        id: 'gid://gitlab/GroupMember/96',
        accessLevel: {
          stringValue: 'GUEST',
          __typename: 'AccessLevel',
        },
        __typename: 'GroupMember',
      },
      requestedBy: {
        id: 'gid://gitlab/User/19',
        username: 'christal',
        webUrl: 'http://localhost:3000/christal',
        name: 'Kassandra Lebsack',
        __typename: 'UserCore',
      },
      newAccessLevel: {
        stringValue: 'DEVELOPER',
        __typename: 'AccessLevel',
      },
      oldAccessLevel: {
        stringValue: 'GUEST',
        __typename: 'AccessLevel',
      },
      status: 'pending',
      createdAt: '2024-07-22T16:25:54Z',
      __typename: 'MemberApproval',
    },
  ],
  pageInfo: {
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: 'eyJpZCI6IjMifQ',
    endCursor: 'eyJpZCI6IjIifQ',
    __typename: 'PageInfo',
  },
  __typename: 'MemberApprovalConnection',
};

export const groupPendingMemberApprovalsQueryMockData = {
  data: {
    group: {
      id: 'gid://gitlab/Group/24',
      pendingMemberApprovals: pendingMemberApprovalsMockData,
      __typename: 'Group',
    },
  },
};

export const projectPendingMemberApprovalsQueryMockData = {
  data: {
    project: {
      id: 'gid://gitlab/Project/24',
      pendingMemberApprovals: pendingMemberApprovalsMockData,
      __typename: 'Project',
    },
  },
};
