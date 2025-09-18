import produce from 'immer';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { STATUS_CATEGORIES_MAP } from 'ee/work_items/constants';

export const updateNamespaceStatuses = ({ store, query, variables, statuses }) => {
  try {
    const sourceData = store.readQuery({
      query,
      variables,
    });

    const updatedStatusData = produce(sourceData, (draftData) => {
      const existingNodes = draftData.namespace.statuses.nodes;

      // Create a map of statuses that should remain/be updated
      const statusMap = new Map();
      statuses.forEach((status) => {
        const key = status.id || status.name;
        statusMap.set(key, status);
      });

      // Remove nodes that are not in the input statuses array/ Delete status
      const filteredNodes = existingNodes.filter((node) => {
        const key = node.id || node.name;
        return statusMap.has(key);
      });

      // Clear the existing nodes array and rebuild it
      existingNodes.length = 0;

      // Add all statuses (updates existing, adds new ones)
      statuses.forEach((status) => {
        const existingNode = filteredNodes.find(
          (node) =>
            (status.id && node.id === status.id) || (!status.id && node.name === status.name),
        );

        if (existingNode) {
          // Update existing node
          existingNodes.push({
            ...existingNode,
            name: status.name,
            iconName: status.category
              ? STATUS_CATEGORIES_MAP[status.category].icon
              : 'status-waiting',
            color: status.color,
            description: status.description,
            category: status.category, // Include category for consistency
            __typename: 'WorkItemStatus',
          });
        } else {
          // Add new node
          existingNodes.push({
            __typename: 'WorkItemStatus',
            id: status.id || null,
            name: status.name,
            iconName: status.category
              ? STATUS_CATEGORIES_MAP[status.category].icon
              : 'status-waiting',
            color: status.color,
            description: status.description,
            category: status.category,
          });
        }
      });
    });

    store.writeQuery({
      query,
      variables,
      data: updatedStatusData,
    });
  } catch (error) {
    Sentry.captureException(error);
  }
};

export const getSelectedStatus = (currentStatus, newStatusOptions) => {
  // check for same status
  const currentStatusExists = newStatusOptions.some((status) => status.id === currentStatus.id);

  if (currentStatusExists) {
    return currentStatus;
  }

  // use a status in the same category
  const sameCategoryStatuses = newStatusOptions.filter(
    (status) => status.category === currentStatus.category,
  );

  if (sameCategoryStatuses.length) {
    return sameCategoryStatuses[0];
  }

  return newStatusOptions[0];
};

export const getNewStatusOptionsFromTheSameState = (currentStatus, newStatusOptions) => {
  const currentStatusCategory = currentStatus.category.toUpperCase();
  const currentStatusState = STATUS_CATEGORIES_MAP[currentStatusCategory]?.workItemState;

  return newStatusOptions.filter((status) => {
    const statusCategory = status.category.toUpperCase();
    const statusState = STATUS_CATEGORIES_MAP[statusCategory]?.workItemState;
    return currentStatusState === statusState;
  });
};

export const getDefaultStatusMapping = (currentLifecycleStatuses, newLifecycleStatuses) => {
  const statusMappings = [];

  currentLifecycleStatuses.forEach((status) => {
    const statusMap = {};
    statusMap.oldStatusId = status.id;

    const eligibleItemsForNewStatus = getNewStatusOptionsFromTheSameState(
      status,
      newLifecycleStatuses,
    );
    const selectedStatus = getSelectedStatus(status, eligibleItemsForNewStatus);
    statusMap.newStatusId = selectedStatus.id;

    statusMappings.push(statusMap);
  });

  return statusMappings;
};
