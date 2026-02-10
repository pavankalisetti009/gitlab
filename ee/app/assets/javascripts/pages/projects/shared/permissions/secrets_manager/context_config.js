import { ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import disableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_secret_manager.mutation.graphql';
import disableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_group_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
import secretsPermissionsQuery from './graphql/secrets_permission.query.graphql';
import groupSecretsPermissionsQuery from './graphql/group_secrets_permission.query.graphql';
import createSecretsPermission from './graphql/create_secrets_permission.mutation.graphql';
import createGroupSecretsPermission from './graphql/create_group_secrets_permission.mutation.graphql';
import deleteSecretsPermission from './graphql/delete_secrets_permission.mutation.graphql';
import deleteGroupSecretsPermission from './graphql/delete_group_secrets_permission.mutation.graphql';

export const SECRETS_MANAGER_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    queries: {
      status: getSecretManagerStatusQuery,
      permissions: secretsPermissionsQuery,
    },
    mutations: {
      enable: enableSecretManagerMutation,
      disable: disableSecretManagerMutation,
      createPermission: createSecretsPermission,
      deletePermission: deleteSecretsPermission,
    },
    resultPaths: {
      status: 'projectSecretsManager',
      enable: 'projectSecretsManagerInitialize',
      disable: 'projectSecretsManagerDeprovision',
    },
  },
  [ENTITY_GROUP]: {
    queries: {
      status: getGroupSecretManagerStatusQuery,
      permissions: groupSecretsPermissionsQuery,
    },
    mutations: {
      enable: enableGroupSecretManagerMutation,
      disable: disableGroupSecretManagerMutation,
      createPermission: createGroupSecretsPermission,
      deletePermission: deleteGroupSecretsPermission,
    },
    resultPaths: {
      status: 'groupSecretsManager',
      enable: 'groupSecretsManagerInitialize',
      disable: 'groupSecretsManagerDeprovision',
    },
  },
};
