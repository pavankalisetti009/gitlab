import {
  ENTITY_PROJECT,
  ENTITY_GROUP,
  GROUP_EVENTS,
  PROJECT_EVENTS,
} from 'ee/ci/secrets/constants';
import {
  getGroupEnvironments,
  getProjectEnvironments,
} from '~/ci/common/private/ci_environments_dropdown';

// project
import getProjectSecrets from 'ee/ci/secrets/graphql/queries/get_project_secrets.query.graphql';
import getProjectSecretsNeedingRotation from 'ee/ci/secrets/graphql/queries/get_project_secrets_needing_rotation.query.graphql';
import getProjectSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getProjectSecretDetails from 'ee/ci/secrets/graphql/queries/get_secret_details.query.graphql';

import createProjectSecret from 'ee/ci/secrets/graphql/mutations/create_project_secret.mutation.graphql';
import updateProjectSecret from 'ee/ci/secrets/graphql/mutations/update_project_secret.mutation.graphql';
import deleteProjectSecret from 'ee/ci/secrets/graphql/mutations/delete_project_secret.mutation.graphql';

// group
import createGroupSecret from 'ee/ci/secrets/graphql/mutations/create_group_secret.mutation.graphql';
import updateGroupSecret from 'ee/ci/secrets/graphql/mutations/update_group_secret.mutation.graphql';

export const SECRETS_MANAGER_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    eventTracking: PROJECT_EVENTS,
    type: ENTITY_PROJECT,
    createSecret: {
      mutation: createProjectSecret,
    },
    deleteSecret: {
      lookup: (data) => data?.projectSecretDelete,
      mutation: deleteProjectSecret,
    },
    environments: {
      lookup: (data) => data?.project?.environments,
      query: getProjectEnvironments,
    },
    getSecretDetails: {
      lookup: (data) => data?.projectSecret,
      query: getProjectSecretDetails,
    },
    getSecrets: {
      lookup: (data) => data?.projectSecrets,
      query: getProjectSecrets,
    },
    getSecretsNeedingRotation: {
      lookup: (data) => data?.projectSecretsNeedingRotation,
      query: getProjectSecretsNeedingRotation,
    },
    getStatus: {
      lookup: (data) => data?.projectSecretsManager,
      query: getProjectSecretManagerStatusQuery,
    },
    updateSecret: {
      mutation: updateProjectSecret,
    },
  },
  [ENTITY_GROUP]: {
    eventTracking: GROUP_EVENTS,
    type: ENTITY_GROUP,
    environments: {
      lookup: (data) => data?.group?.environmentScopes,
      query: getGroupEnvironments,
    },
    createSecret: {
      mutation: createGroupSecret,
    },
    updateSecret: {
      mutation: updateGroupSecret,
    },
  },
};
