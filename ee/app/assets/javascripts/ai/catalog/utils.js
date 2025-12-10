import { sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const prerequisitesPath = helpPagePath('user/duo_agent_platform/ai_catalog', {
  anchor: 'view-the-ai-catalog',
});

export const prerequisitesError = (message, params = {}) => {
  return sprintf(
    message,
    {
      linkStart: `<a href="${prerequisitesPath}" target="_blank">`,
      linkEnd: '</a>',
      ...params,
    },
    false,
  );
};

/**
 * Note that this utility method *does not* use the `pinnedItemVersion`.
 */
export const getLatestUpdatedAt = (item) => {
  return item.latestVersion.updatedAt > item.updatedAt
    ? item.latestVersion.updatedAt
    : item.updatedAt;
};

/**
 * Helper to retrieve nested version data so we don't have to pass duplicate objects around.
 *
 * @param {Object} obj - an Item or ItemConsumer
 * @param {String} keys - a dot-notated stringh where each item is a key in the obj, leading to the nested value.
 *
 * @example
 * ```
 * const pinnedVersionKey = 'configurationForProject.pinnedItemVersion';
 * const latestVersionKey = 'latestVersion';
 * ```
 */
export const getByVersionKey = (obj, keys) => {
  return (keys || '').split('.').reduce((acc, key) => acc?.[key], obj);
};
