import { s__ } from '~/locale';

const AVAILABILITY_OPTIONS = {
  AVAILABLE: 'available',
  BLOCKED: 'blocked',
};

export const CONNECTION_STATUS = {
  CONNECTED: 'connected',
  NOT_CONNECTED: 'not_connected',
};

export const AVAILABILITY_TEXT = {
  [AVAILABILITY_OPTIONS.AVAILABLE]: s__('Workspaces|Available'),
  [AVAILABILITY_OPTIONS.BLOCKED]: s__('Workspaces|Blocked'),
};

export const CONNECTION_STATUS_TEXT = {
  [CONNECTION_STATUS.CONNECTED]: s__('Workspaces|Connected'),
  [CONNECTION_STATUS.NOT_CONNECTED]: s__('Workspaces|Not connected'),
};
