const TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD = 'SecretPermissionUpdatePayload';
const TYPENAME_SECRET_PERMISSION = 'SecretPermission';

export const secretManagerSettingsResponse = (status, errors = undefined) => {
  return {
    data: {
      projectSecretsManager: {
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
    errors,
  };
};

export const initializeSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      projectSecretsManagerInitialize: {
        errors,
        projectSecretsManager: {
          status: 'PROVISIONING',
        },
        __typename: 'ProjectSecretsManagerInitializePayload',
      },
    },
  };
};

export const MOCK_USERS_API = [
  {
    id: 1,
    avatarUrl: '/uploads/-/system/user/avatar/1/avatar.png',
    name: 'Administrator',
    username: 'root',
    value: 'root',
  },
  {
    id: 2,
    avatarUrl: '/uploads/-/system/user/avatar/2/avatar.png',
    name: 'John Doe',
    username: 'john.doe',
    value: 'john.doe',
  },
];

export const MOCK_GROUPS_API = [
  {
    id: 11,
    value: 11,
    avatarUrl: '/uploads/-/system/user/avatar/3/avatar.png',
    name: 'Organization',
    username: 'organization',
  },
  {
    id: 22,
    value: 22,
    avatarUrl: '/uploads/-/system/user/avatar/4/avatar.png',
    name: 'test-org',
    username: 'test-org',
  },
];

export const mockCreatePermissionResponse = {
  data: {
    secretPermissionUpdate: {
      secretPermission: {
        principal: {
          id: 1,
          type: 'Role',
          __typename: 'Principal',
        },
        permissions: ['read', 'create'],
        __typename: TYPENAME_SECRET_PERMISSION,
      },
      errors: [],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
};

export const mockCreatePermissionErrorResponse = (errorMessage) => ({
  data: {
    secretPermissionUpdate: {
      secretPermission: null,
      errors: [errorMessage],
      __typename: TYPENAME_SECRET_PERMISSION_UPDATE_PAYLOAD,
    },
  },
});

export const ROOT_USER_DETAILS = {
  id: 'gid://gitlab/User/1',
  username: 'root',
  name: 'Administrator',
  avatarUrl:
    'https://www.gravatar.com/avatar/85366df1bc2e8979432dbdafee989bce82734d876698ec4c6cd847b9ae1fedf2?s=80&d=identicon',
  webUrl: 'http://gdk.test:3000/root',
};

export const OWNER_PERMISSION_NODE = {
  grantedBy: null,
  permissions: '["create", "read", "update", "delete"]',
  principal: {
    id: 50,
    type: 'ROLE',
    userRoleId: null,
    user: null,
    group: null,
  },
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const ROLE_PERMISSION_NODE = {
  grantedBy: { ...ROOT_USER_DETAILS },
  permissions: '["read", "create"]',
  principal: {
    id: 20,
    type: 'ROLE',
    userRoleId: null,
    user: null,
    group: null,
  },
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const GROUP_PERMISSION_NODE = {
  grantedBy: {
    id: 'gid://gitlab/User/4',
    username: 'lonnie',
    name: 'Lon Lonnie',
    avatarUrl:
      'https://www.gravatar.com/avatar/1e8e3e4b8471a36396bee959a2c31f6fd03ae08a2560bab45205fa795f79f4cf?s=80&d=identicon',
    webUrl: 'http://gdk.test:3000/lonnie',
  },
  permissions: '["read", "create", "update"]',
  principal: {
    id: 22,
    type: 'GROUP',
    userRoleId: null,
    user: null,
    group: {
      id: 'gid://gitlab/Group/22',
      name: 'Toolbox',
      avatarUrl: null,
      webUrl: 'http://gdk.test:3000/groups/toolbox',
    },
  },
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const USER_PERMISSION_NODE = {
  grantedBy: { ...ROOT_USER_DETAILS },
  permissions: '["read", "delete"]',
  principal: {
    id: 49,
    type: 'USER',
    userRoleId: 40,
    user: {
      id: 'gid://gitlab/User/49',
      username: 'kristina.moen',
      name: 'Ginny McGlynn',
      avatarUrl:
        'https://www.gravatar.com/avatar/c491e205f3fc6673ee13fe84efdcad77301b884bdaa5274deb72dafd9c03108e?s=80&d=identicon',
      webUrl: 'http://gdk.test:3000/kristina.moen',
    },
    group: null,
  },
  project: {
    id: 'gid://gitlab/Project/24',
  },
};

export const mockPermissionsQueryResponse = (errors = undefined) => ({
  data: {
    errors,
    secretPermissions: {
      edges: [
        {
          node: OWNER_PERMISSION_NODE,
        },
        {
          node: ROLE_PERMISSION_NODE,
        },
        {
          node: GROUP_PERMISSION_NODE,
        },
        {
          node: USER_PERMISSION_NODE,
        },
      ],
    },
  },
});
