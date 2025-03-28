import { s__ } from '~/locale';

const GEO_SHARED_STATUS_STATES = {
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

export const REPLICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SYNCED: {
    title: s__('Geo|Synced'),
    value: 'SYNCED',
    variant: 'success',
  },
};

export const VERIFICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SUCCEEDED: {
    title: s__('Geo|Succeeded'),
    value: 'SUCCEEDED',
    variant: 'success',
  },
  DISABLED: {
    title: s__('Geo|Disabled'),
    value: 'DISABLED',
    variant: 'neutral',
  },
};
