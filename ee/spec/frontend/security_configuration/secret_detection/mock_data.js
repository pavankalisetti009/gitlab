export const projectSecurityExclusions = [
  {
    id: 'gid://gitlab/Security::ProjectSecurityExclusion/1',
    scanner: 'SECRET_PUSH_PROTECTION',
    type: 'PATH',
    active: true,
    description: 'test1',
    value: 'tmp',
    __typename: 'ProjectSecurityExclusion',
  },
  {
    id: 'gid://gitlab/Security::ProjectSecurityExclusion/29',
    scanner: 'SECRET_PUSH_PROTECTION',
    type: 'RAW_VALUE',
    active: true,
    description: 'test secret',
    value: 'glpat-1234567890abcdefg',
    __typename: 'ProjectSecurityExclusion',
  },
];
