import { sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { VERSION_LATEST, VERSION_PINNED, VERSION_PINNED_GROUP } from './constants';

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

/**
 * @important Project config should always take precedence over group config for pinned versions.
 */
const resolveVersionKey = (item, isGlobal) => {
  if (isGlobal) return VERSION_LATEST;
  if (item?.configurationForProject) return VERSION_PINNED;
  if (item?.configurationForGroup) return VERSION_PINNED_GROUP;
  return VERSION_LATEST;
};

/**
 * Determines version based on scope configuration priority:
 * 1. Project config > VERSION_PINNED
 * 2. Group config > VERSION_PINNED_GROUP
 * 3. Global or no configs present > VERSION_LATEST
 */
export const resolveVersion = (item, isGlobal) => {
  const key = resolveVersionKey(item, isGlobal);
  const data = getByVersionKey(item, key);

  return {
    ...data,
    key,
  };
};
