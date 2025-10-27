import { sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const mapSteps = (steps) =>
  steps.nodes.map((s) => ({
    id: s.agent.id,
    name: s.agent.name,
    versions: s.agent.versions,
    versionName: s.pinnedVersionPrefix,
  }));

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

export const getLatestUpdatedAt = (item) => {
  return item.latestVersion.updatedAt > item.updatedAt
    ? item.latestVersion.updatedAt
    : item.updatedAt;
};
