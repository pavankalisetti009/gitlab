import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import DuoAgentsPlatformBreadcrumbs from './router/duo_agents_platform_breadcrumbs.vue';
import { activeNavigationWatcher } from './router/utils';
import { createRouter } from './router';
import DuoAgentsPlatformApp from './duo_agents_platform_app.vue';
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
  const { agentsPlatformBaseRoute, duoAgentsInvokePath, emptyStateIllustrationPath } = dataset;
  const namespaceProvideData = getNamespaceDatasetProperties(dataset, namespaceDatasetProperties);

  if (namespaceDatasetProperties.length !== Object.keys(namespaceProvideData).length) {
    throw new Error(
      `One or more required properties are missing in the dataset:
       Expected these properties: [${namespaceDatasetProperties.join(', ')}]
       but received these: [${Object.keys(namespaceProvideData).join(', ')}],
      `,
    );
  }

  const router = createRouter(agentsPlatformBaseRoute, namespace);
  router.beforeEach(activeNavigationWatcher);

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  injectVueAppBreadcrumbs(router, DuoAgentsPlatformBreadcrumbs);

  return new Vue({
    el,
    name: 'DuoAgentsPlatformApp',
    router,
    apolloProvider,
    provide: {
      duoAgentsInvokePath,
      emptyStateIllustrationPath,
      ...namespaceProvideData,
    },
    render(h) {
      return h(DuoAgentsPlatformApp);
    },
  });
};
