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
export const SECRET_MANAGER_STATUS_ACTIVE = 'ACTIVE';
export const SECRET_MANAGER_STATUS_INACTIVE = 'INACTIVE';
export const SECRET_MANAGER_STATUS_PROVISIONING = 'PROVISIONING';

export const SECRET_STATUS = {
  disabled: {
    icon: 'status-failed',
    text: __('Disabled'),
    variant: 'neutral',
  },
  enabled: {
    icon: 'status-active',
    text: __('Enabled'),
    variant: 'success',
  },
  expiring: {
    icon: 'status-alert',
    text: __('Expiring soon'),
    variant: 'warning',
  },
  expired: {
    icon: 'status-cancelled',
    text: __('Expired'),
    variant: 'danger',
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
