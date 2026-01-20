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
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import getSecretDetails from 'ee/ci/secrets/graphql/queries/get_secret_details.query.graphql';

export const SECRETS_MANAGER_CONTEXT_CONFIG = {
  [ENTITY_PROJECT]: {
    eventTracking: PROJECT_EVENTS,
    type: ENTITY_PROJECT,
    environments: {
      lookup: (data) => data?.project?.environments,
      query: getProjectEnvironments,
    },
    getSecretDetails: {
      lookup: (data) => data?.projectSecret,
      query: getSecretDetails,
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
      query: getSecretManagerStatusQuery,
    },
  },
  [ENTITY_GROUP]: {
    eventTracking: GROUP_EVENTS,
    type: ENTITY_GROUP,
    environments: {
      lookup: (data) => data?.group?.environmentScopes,
      query: getGroupEnvironments,
    },
  },
};
