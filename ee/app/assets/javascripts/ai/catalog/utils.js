import { sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from './constants';

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

export function createAvailableFlowItemTypes({ isFlowsEnabled, isThirdPartyFlowsEnabled }) {
  const types = [];

  if (isFlowsEnabled) {
    types.push(AI_CATALOG_TYPE_FLOW);
  }

  if (isThirdPartyFlowsEnabled) {
    types.push(AI_CATALOG_TYPE_THIRD_PARTY_FLOW);
  }

  return types;
}
