export const adminRoles = [
  {
    id: 'gid://gitlab/MemberRole/1',
    name: 'Admin role 1',
    description: 'Admin role 1 description',
    enabledPermissions: {
      nodes: [{ name: 'A' }, { name: 'B' }],
    },
  },
  {
    id: 'gid://gitlab/MemberRole/2',
    name: 'Admin role 2',
    description: 'Admin role 2 description',
    enabledPermissions: {
      nodes: [{ name: 'C' }, { name: 'D' }],
    },
  },
];

export const adminRole = { id: 12, name: 'Custom admin role', ldap: false };
export const ldapRole = { id: 14, name: 'LDAP assigned role', ldap: true };
