import { __, s__ } from '~/locale';

export const SECRET_DESCRIPTION_MAX_LENGTH = 200;
export const BRANCH_QUERY_LIMIT = 100;

export const INDEX_ROUTE_NAME = 'index';
export const NEW_ROUTE_NAME = 'new';
export const DETAILS_ROUTE_NAME = 'details';
export const EDIT_ROUTE_NAME = 'edit';

export const SCOPED_LABEL_COLOR = '#CBE2F9';
export const UNSCOPED_LABEL_COLOR = '#DCDCDE';

export const PAGE_SIZE = 10;

// contexts the secrets manager page works in
export const ENTITY_GROUP = 'group';
export const ENTITY_PROJECT = 'project';
export const ACCEPTED_CONTEXTS = [ENTITY_GROUP, ENTITY_PROJECT];

export const ACTION_ENABLE_SECRET_MANAGER = 'ENABLE_SECRET_MANAGER';
export const ACTION_DISABLE_SECRET_MANAGER = 'DISABLE_SECRET_MANAGER';
export const SECRET_MANAGER_STATUS_ACTIVE = 'ACTIVE';
export const SECRET_MANAGER_STATUS_INACTIVE = 'INACTIVE';
export const SECRET_MANAGER_STATUS_PROVISIONING = 'PROVISIONING';
export const SECRET_MANAGER_STATUS_DEPROVISIONING = 'DEPROVISIONING';

export const SECRET_STATUS_ICONS_OPTICALLY_ALIGNED = [
  'COMPLETED',
  'CREATE_IN_PROGRESS',
  'UPDATE_IN_PROGRESS',
];

export const SECRET_STATUS = {
  COMPLETED: {
    icon: 'status-success',
    iconSize: 'sm',
    variant: 'success',
    text: __('Healthy'),
    description: s__('SecretsManager|Secret created or updated successfully.'),
  },
  CREATE_IN_PROGRESS: {
    icon: 'status-running',
    iconSize: 'sm',
    variant: 'neutral',
    text: __('Creating'),
    description: s__('SecretsManager|Secret is being created.'),
  },
  CREATE_STALE: {
    icon: 'warning-solid',
    iconSize: 'sm',
    variant: 'danger',
    text: __('Needs attention'),
    description: s__('SecretsManager|Secret creation failed. Delete the secret and try again.'),
  },
  UPDATE_IN_PROGRESS: {
    icon: 'status-running',
    iconSize: 'sm',
    variant: 'neutral',
    text: __('Updating'),
    description: s__('SecretsManager|Secret is being updated.'),
  },
  UPDATE_STALE: {
    icon: 'warning-solid',
    iconSize: 'sm',
    variant: 'danger',
    text: __('Needs attention'),
    description: s__('SecretsManager|Secret update failed. Retry the update or delete the secret.'),
  },
};

export const SECRET_ROTATION_STATUS = {
  approaching: 'APPROACHING',
  overdue: 'OVERDUE',
};

export const POLL_INTERVAL = 2000;

export const FAILED_TO_LOAD_ERROR_MESSAGE = s__(
  'SecretsManager|Failed to load secret. Please try again later.',
);

// event tracking
export const GROUP_EVENTS = {
  pageVisit: 'visit_group_secrets_manager',
};

export const PROJECT_EVENTS = {
  pageVisit: 'visit_project_secrets_manager',
};

export const PAGE_VISIT_EDIT = 'edit_form';
export const PAGE_VISIT_NEW = 'create_form';
export const PAGE_VISIT_SECRET_DETAILS = 'secret_details_page';
export const PAGE_VISIT_SECRETS_TABLE = 'secrets_table_page';
