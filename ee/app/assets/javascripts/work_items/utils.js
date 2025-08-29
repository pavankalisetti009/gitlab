import { uniqBy } from 'lodash';
import { isStatusWidget } from '~/work_items/utils';
import { STATUS_CATEGORIES } from 'ee/work_items/constants';

/**
 * Takes `namespace.workItemTypes.nodes` and returns a merged list of allowed statuses
 * sorted by category.
 *
 * @param workItemTypes `namespace.workItemTypes.nodes` from GraphQL
 * @returns {Object} a merged list of allowed statuses sorted by category
 */
export const getStatuses = (workItemTypes) => {
  const statusesMap = new Map();
  Object.values(STATUS_CATEGORIES).forEach((category) => {
    statusesMap.set(category.toLowerCase(), []);
  });

  workItemTypes?.forEach((workItemType) => {
    workItemType?.widgetDefinitions?.find(isStatusWidget)?.allowedStatuses?.forEach((status) => {
      statusesMap.get(status.category).push(status);
    });
  });

  return uniqBy(Array.from(statusesMap.values()).flat(), 'id');
};
