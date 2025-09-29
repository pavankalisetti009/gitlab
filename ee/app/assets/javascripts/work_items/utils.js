import { uniqBy } from 'lodash';
import { isStatusWidget } from '~/work_items/utils';
import {
  DEFAULT_STATE_CLOSED,
  DEFAULT_STATE_DUPLICATE,
  DEFAULT_STATE_OPEN,
  STATUS_CATEGORIES,
} from 'ee/work_items/constants';

export const getDefaultStateType = (lifecycle, status) => {
  if (lifecycle.defaultClosedStatus?.id === status.id) {
    return DEFAULT_STATE_CLOSED;
  }
  if (lifecycle.defaultDuplicateStatus?.id === status.id) {
    return DEFAULT_STATE_DUPLICATE;
  }
  if (lifecycle.defaultOpenStatus?.id === status.id) {
    return DEFAULT_STATE_OPEN;
  }
  return null;
};

/**
 * Takes a list of statuses and returns a unique list of statuses sorted by category.
 *
 * @param {WorkItemStatus[]} statuses statuses
 * @returns {WorkItemStatus[]} a merged list of allowed statuses sorted by category
 */
export const sortStatuses = (statuses) => {
  const statusesMap = new Map();
  Object.values(STATUS_CATEGORIES).forEach((category) => {
    statusesMap.set(category.toLowerCase(), []);
  });

  statuses.forEach((status) => {
    statusesMap.get(status.category).push(status);
  });

  return uniqBy(Array.from(statusesMap.values()).flat(), 'id');
};

/**
 * Takes `namespace.workItemTypes.nodes` and returns a unique list of allowed statuses
 * sorted by category.
 *
 * @param {WorkItemType[]} workItemTypes `namespace.workItemTypes.nodes` from GraphQL
 * @returns {WorkItemStatus[]} a unique list of allowed statuses sorted by category
 */
export const getStatuses = (workItemTypes) => {
  const statuses = workItemTypes
    ?.map((workItemType) => workItemType?.widgetDefinitions?.find(isStatusWidget)?.allowedStatuses)
    .filter((allowedStatuses) => Boolean(allowedStatuses))
    .flat();
  return sortStatuses(statuses);
};
