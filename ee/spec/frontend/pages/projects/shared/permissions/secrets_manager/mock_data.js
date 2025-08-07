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
