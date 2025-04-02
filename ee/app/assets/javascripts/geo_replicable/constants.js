import { GlFilteredSearchToken } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export const FILTER_STATES = {
  ALL: {
    label: __('All'),
    value: '',
  },
  STARTED: {
    label: __('Started'),
    value: 'started',
  },
  PENDING: {
    label: __('In progress'),
    value: 'pending',
  },
  SYNCED: {
    label: __('Synced'),
    value: 'synced',
  },
  FAILED: {
    label: __('Failed'),
    value: 'failed',
  },
};

export const FILTER_OPTIONS = Object.values(FILTER_STATES);

export const DEFAULT_STATUS = 'never';

export const STATUS_ICON_NAMES = {
  [FILTER_STATES.STARTED.value]: 'clock',
  [FILTER_STATES.SYNCED.value]: 'check-circle-filled',
  [FILTER_STATES.PENDING.value]: 'status_pending',
  [FILTER_STATES.FAILED.value]: 'status_failed',
  [DEFAULT_STATUS]: 'status_notfound',
};

export const STATUS_ICON_CLASS = {
  [FILTER_STATES.STARTED.value]: 'gl-text-warning',
  [FILTER_STATES.SYNCED.value]: 'gl-text-success',
  [FILTER_STATES.PENDING.value]: 'gl-text-warning',
  [FILTER_STATES.FAILED.value]: 'gl-text-danger',
  [DEFAULT_STATUS]: 'gl-text-subtle',
};

export const DEFAULT_SEARCH_DELAY = 500;

export const ACTION_TYPES = {
  RESYNC: 'resync',
  REVERIFY: 'reverify',
  RESYNC_ALL: 'resync_all',
  REVERIFY_ALL: 'reverify_all',
};

export const PREV = 'prev';

export const NEXT = 'next';

export const DEFAULT_PAGE_SIZE = 20;

export const GEO_BULK_ACTION_MODAL_ID = 'geo-bulk-action';

export const GEO_TROUBLESHOOTING_LINK = helpPagePath(
  'administration/geo/replication/troubleshooting/_index.md',
);

export const REPLICATION_STATUS_STATES = {
  PENDING: {
    title: __('Pending'),
    value: 'pending',
  },
  STARTED: {
    title: __('Started'),
    value: 'started',
  },
  SYNCED: {
    title: __('Synced'),
    value: 'synced',
  },
  FAILED: {
    title: __('Failed'),
    value: 'failed',
  },
};

export const REPLICATION_STATUS_STATES_ARRAY = Object.values(REPLICATION_STATUS_STATES);

export const TOKEN_TYPES = {
  REPLICABLE_TYPE: 'replicable_type',
  REPLICATION_STATUS: 'replication_status',
};

export const FILTERED_SEARCH_TOKEN_DEFINITIONS = [
  {
    title: s__('Geo|Replication status'),
    type: TOKEN_TYPES.REPLICATION_STATUS,
    icon: 'substitute',
    token: GlFilteredSearchToken,
    operators: OPERATORS_IS,
    unique: true,
  },
];
