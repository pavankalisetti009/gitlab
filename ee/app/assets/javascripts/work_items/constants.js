import * as CE from '~/work_items/constants';
import { s__ } from '~/locale';

/*
 * We're disabling the import/export rule here because we want to
 * re-export the constants from the CE file while also overriding
 * anything that's EE-specific.
 */
/* eslint-disable import/export */
export * from '~/work_items/constants';

export const optimisticUserPermissions = {
  ...CE.optimisticUserPermissions,
  blockedWorkItems: true,
};

export const newWorkItemOptimisticUserPermissions = {
  ...CE.newWorkItemOptimisticUserPermissions,
  blockedWorkItems: true,
};
/* eslint-enable import/export */

export const STATUS_CATEGORIES = {
  TRIAGE: 'TRIAGE',
  TO_DO: 'TO_DO',
  IN_PROGRESS: 'IN_PROGRESS',
  DONE: 'DONE',
  CANCELED: 'CANCELED',
};

export const STATUS_CATEGORIES_MAP = {
  [STATUS_CATEGORIES.TRIAGE]: {
    icon: 'status-neutral',
    color: '#995715',
    label: s__('WorkItem|Triage'),
    defaultState: 'open',
    workItemState: CE.STATE_OPEN,
    description: s__(
      'WorkItem|Use for items that are still in a proposal or ideation phase, not yet accepted or planned for work.',
    ),
  },
  [STATUS_CATEGORIES.TO_DO]: {
    icon: 'status-waiting',
    color: '#737278',
    label: s__('WorkItem|To do'),
    defaultState: 'open',
    workItemState: CE.STATE_OPEN,
    description: s__('WorkItem|Use for planned work that is not actively being worked on.'),
  },
  [STATUS_CATEGORIES.IN_PROGRESS]: {
    icon: 'status-running',
    color: '#1f75cb',
    label: s__('WorkItem|In progress'),
    defaultState: 'open',
    workItemState: CE.STATE_OPEN,
    description: s__('WorkItem|Use for items that are actively being worked on.'),
  },
  [STATUS_CATEGORIES.DONE]: {
    icon: 'status-success',
    color: '#108548',
    label: s__('WorkItem|Done'),
    defaultState: 'closed',
    workItemState: CE.STATE_CLOSED,
    description: s__(
      'WorkItem|Use for items that have been completed. Applying a done status will close the item.',
    ),
  },
  [STATUS_CATEGORIES.CANCELED]: {
    icon: 'status-cancelled',
    color: '#dd2b0e',
    label: s__('WorkItem|Canceled'),
    defaultState: 'duplicate',
    workItemState: CE.STATE_CLOSED,
    description: s__(
      'WorkItem|Use for items that are no longer relevant and will not be completed. Applying a canceled status will close the item.',
    ),
  },
};
