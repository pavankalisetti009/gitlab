export const mockDefaultPermissions = [
  { value: 'A', name: 'A', description: 'A', requirements: null },
  { value: 'B', name: 'B', description: 'B', requirements: ['A'] },
  { value: 'C', name: 'C', description: 'C', requirements: ['B'] }, // Nested dependency: C -> B -> A
  { value: 'D', name: 'D', description: 'D', requirements: ['C'] }, // Nested dependency: D -> C -> B -> A
  { value: 'E', name: 'E', description: 'E', requirements: ['F'] }, // Circular dependency
  { value: 'F', name: 'F', description: 'F', requirements: ['E'] }, // Circular dependency
  { value: 'G', name: 'G', description: 'G', requirements: ['A', 'B', 'C'] }, // Multiple dependencies
];

export const mockPermissionsResponse = {
  data: {
    memberRolePermissions: {
      nodes: mockDefaultPermissions,
    },
  },
};

export const mockEmptyMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      memberRoles: {
        nodes: [],
      },
    },
  },
};

export const mockMemberRoles = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
      memberRoles: {
        nodes: [
          {
            baseAccessLevel: {
              humanAccess: 'Reporter',
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/1',
            name: 'Test',
            description: 'Test description',
            membersCount: 0,
            editPath: 'edit/path',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
                {
                  name: 'Read vulnerability',
                  value: 'READ_VULNERABILITY',
                },
              ],
            },
            __typename: 'MemberRole',
          },
          {
            baseAccessLevel: {
              humanAccess: 'Reporter',
              __typename: 'AccessLevel',
            },
            id: 'gid://gitlab/MemberRole/2',
            name: 'Test 2',
            description: '',
            membersCount: 1,
            editPath: 'edit/path',
            enabledPermissions: {
              nodes: [
                {
                  name: 'Read code',
                  value: 'READ_CODE',
                },
                {
                  name: 'Read vulnerability',
                  value: 'READ_VULNERABILITY',
                },
              ],
            },
            __typename: 'MemberRole',
          },
        ],
        __typename: 'MemberRoleConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockInstanceMemberRoles = {
  data: {
    memberRoles: {
      nodes: [
        {
          baseAccessLevel: {
            humanAccess: 'Guest',
            __typename: 'AccessLevel',
          },
          id: 'gid://gitlab/MemberRole/2',
          name: 'Instance Test',
          description: 'Instance Test description',
          membersCount: 0,
          editPath: 'edit/path',
          enabledPermissions: {
            nodes: [
              {
                name: 'Admin group',
                value: 'ADMIN_GROUP',
              },
            ],
          },
          __typename: 'MemberRole',
        },
      ],
      __typename: 'MemberRoleConnection',
    },
  },
};

export const mockMemberRole = {
  id: 1,
  name: 'Custom role',
  description: 'Custom role description',
  createdAt: '2024-08-04T12:20:43Z',
  editPath: 'role/edit/path',
  membersCount: 0,
  baseAccessLevel: { stringValue: 'DEVELOPER', humanAccess: 'Developer' },
  enabledPermissions: {
    nodes: [
      { name: 'Permission A', value: 'A' },
      { name: 'Permission B', value: 'B' },
    ],
  },
  __typename: 'MemberRole',
};

export const getMemberRoleQueryResponse = (memberRole = mockMemberRole) => ({
  data: { memberRole },
});
