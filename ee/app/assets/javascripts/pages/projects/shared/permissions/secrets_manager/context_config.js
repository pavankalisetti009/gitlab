import { ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import disableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_secret_manager.mutation.graphql';
import disableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_group_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';

export const SECRETS_MANAGER_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    queries: {
      status: getSecretManagerStatusQuery,
    },
    mutations: {
      enable: enableSecretManagerMutation,
      disable: disableSecretManagerMutation,
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
    },
    mutations: {
      enable: enableGroupSecretManagerMutation,
      disable: disableGroupSecretManagerMutation,
    },
    resultPaths: {
      status: 'groupSecretsManager',
      enable: 'groupSecretsManagerInitialize',
      disable: 'groupSecretsManagerDeprovision',
    },
  },
};
