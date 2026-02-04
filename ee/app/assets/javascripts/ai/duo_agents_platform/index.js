import { initSinglePageApplication } from '~/vue_shared/spa';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createRouter } from './router';
import { getNamespaceDatasetProperties } from './utils';

export const initDuoAgentsPlatformPage = ({ namespaceDatasetProperties = [], namespace }) => {
  if (!namespace) {
    throw new Error(`Namespace is required for the DuoAgentPlatform page to function`);
  }
  const selector = '#js-duo-agents-platform-page';

  const el = document.querySelector(selector);
  if (!el) {
    return null;
  }

  const { dataset } = el;

  const {
    agentsPlatformBaseRoute,
    exploreAiCatalogPath,
    aiImpactDashboardEnabled,
    aiImpactDashboardPath,
  } = dataset;
  const namespaceProvideData = getNamespaceDatasetProperties(dataset, namespaceDatasetProperties);

  if (namespaceDatasetProperties.length !== Object.keys(namespaceProvideData).length) {
    throw new Error(
      `One or more required properties are missing in the dataset:
       Expected these properties: [${namespaceDatasetProperties.join(', ')}]
       but received these: [${Object.keys(namespaceProvideData).join(', ')}].
      `,
    );
  }

  const router = createRouter(agentsPlatformBaseRoute, namespace);

  return initSinglePageApplication({
    name: 'AiDuoAgentsPlatformRoot',
    router,
    el,
    provide: {
      exploreAiCatalogPath,
      aiImpactDashboardPath,
      aiImpactDashboardEnabled: parseBoolean(aiImpactDashboardEnabled),
      ...namespaceProvideData,
    },
  });
};
