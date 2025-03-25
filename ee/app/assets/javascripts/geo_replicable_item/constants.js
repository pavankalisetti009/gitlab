import { s__ } from '~/locale';

export const REPLICATION_STATUS_STATES = {
  PENDING: {
    title: s__('Geo|Pending'),
    value: 'PENDING',
    variant: 'warning',
  },
  STARTED: {
    title: s__('Geo|Started'),
    value: 'STARTED',
    variant: 'info',
  },
  SYNCED: {
    title: s__('Geo|Synced'),
    value: 'SYNCED',
    variant: 'success',
  },
  FAILED: {
    title: s__('Geo|Failed'),
    value: 'FAILED',
    variant: 'danger',
  },
  UNKNOWN: {
    title: s__('Geo|Unknown'),
    value: null,
    variant: 'muted',
  },
};
