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

export const standardRoles = [
  {
    accessLevel: 5,
    name: 'Minimal Access',
    membersCount: 0,
    detailsPath: 'role/MINIMAL_ACCESS',
    description:
      'The Minimal Access role is for users who need the least amount of access into groups and projects. You can assign this role as a default, before giving a user another role with more permissions.',
  },
  {
    accessLevel: 10,
    name: 'Guest',
    membersCount: 1,
    detailsPath: 'role/GUEST',
    description:
      'The Guest role is for users who need visibility into a project or group but should not have the ability to make changes, such as external stakeholders.',
  },
  {
    accessLevel: 20,
    name: 'Reporter',
    membersCount: 2,
    detailsPath: 'role/REPORTER',
    description:
      'The Reporter role is suitable for team members who need to stay informed about a project or group but do not actively contribute code.',
  },
  {
    accessLevel: 30,
    name: 'Developer',
    membersCount: 3,
    detailsPath: 'role/DEVELOPER',
    description:
      'The Developer role strikes a balance between giving users the necessary access to contribute code while restricting sensitive administrative actions.',
  },
  {
    accessLevel: 40,
    name: 'Maintainer',
    membersCount: 4,
    detailsPath: 'role/MAINTAINER',
    description:
      'The Maintainer role is primarily used for managing code reviews, approvals, and administrative settings for projects. This role can also manage project memberships.',
  },
  {
    accessLevel: 50,
    name: 'Owner',
    membersCount: 5,
    detailsPath: 'role/OWNER',
    description:
      'The Owner role is normally assigned to the individual or team responsible for managing and maintaining the group or creating the project. This role has the highest level of administrative control, and can manage all aspects of the group or project, including managing other Owners.',
  },
];

export const memberRoles = [
  {
    id: 'gid://gitlab/MemberRole/1',
    name: 'Custom role 1',
    description: 'Custom role 1 description',
    membersCount: 0,
    editPath: 'edit/path/1',
    detailsPath: 'details/path/1',
    __typename: 'MemberRole',
  },
  {
    id: 'gid://gitlab/MemberRole/2',
    name: 'Custom role 2',
    description: 'Custom role 2 description',
    membersCount: 1,
    editPath: 'edit/path/2',
    detailsPath: 'details/path/2',
    __typename: 'MemberRole',
  },
];

export const groupMemberRolesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      standardRoles: { nodes: standardRoles, __typename: 'StandardRoleConnection' },
      memberRoles: { nodes: memberRoles },
      __typename: 'Group',
    },
  },
};

export const instanceMemberRolesResponse = {
  data: {
    standardRoles: { nodes: standardRoles, __typename: 'StandardRoleConnection' },
    memberRoles: { nodes: memberRoles },
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
  enabledPermissions: { nodes: [{ value: 'A' }, { value: 'B' }] },
  __typename: 'MemberRole',
};

export const getMemberRoleQueryResponse = (memberRole = mockMemberRole) => ({
  data: { memberRole },
});
