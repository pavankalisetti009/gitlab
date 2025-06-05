import { s__ } from '~/locale';

export const AVAILABILITY_OPTIONS = {
  AVAILABLE: 'available',
  BLOCKED: 'blocked',
};

export const AVAILABILITY_TEXT = {
  [AVAILABILITY_OPTIONS.AVAILABLE]: s__('Workspaces|Available'),
  [AVAILABILITY_OPTIONS.BLOCKED]: s__('Workspaces|Blocked'),
};
