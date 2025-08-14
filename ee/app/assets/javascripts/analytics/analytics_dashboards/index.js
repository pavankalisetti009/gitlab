import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { convertArrayToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import DashboardsApp from './dashboards_app.vue';
import createRouter from './router';
import AnalyticsDashboardsBreadcrumbs from './components/analytics_dashboards_breadcrumbs.vue';

export default () => {
  const el = document.getElementById('js-analytics-dashboards-list-app');

  if (!el) {
    return false;
  }

  const {
    canConfigureProjectSettings: canConfigureProjectSettingsString,
    canSelectGitlabManagedProvider,
    managedClusterPurchased,
    trackingKey,
    namespaceId,
    namespaceName,
    namespaceFullPath,
    isProject: isProjectStr,
    isGroup,
    collectorHost,
    dashboardEmptyStateIllustrationPath,
    analyticsSettingsPath,
    routerBase,
    features,
    rootNamespaceName,
    rootNamespaceFullPath,
    dataSourceClickhouse,
    topicsExploreProjectsPath,
    isInstanceConfiguredWithSelfManagedAnalyticsProvider,
    defaultUseInstanceConfiguration,
    overviewCountsAggregationEnabled,
    hasScopedLabelsFeature,
  } = el.dataset;

  const canConfigureProjectSettings = parseBoolean(canConfigureProjectSettingsString);

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(
      {},
      {
        cacheConfig: {
          typePolicies: {
            Project: {
              fields: {
                customizableDashboards: {
                  keyArgs: ['projectPath', 'slug'],
                },
              },
            },
            CustomizableDashboards: {
              keyFields: ['slug'],
            },
          },
        },
      },
    ),
  });

  // This is a mini state to help the breadcrumb have the correct name
  const breadcrumbState = Vue.observable({
    name: '',
    updateName(value) {
      this.name = value;
    },
  });
  const isProject = parseBoolean(isProjectStr);

  const router = createRouter(routerBase, breadcrumbState, {
    canConfigureProjectSettings,
  });

  injectVueAppBreadcrumbs(router, AnalyticsDashboardsBreadcrumbs);

  return new Vue({
    el,
    name: 'AnalyticsDashboardsRoot',
    apolloProvider,
    router,
    provide: {
      breadcrumbState,
      canConfigureProjectSettings,
      canSelectGitlabManagedProvider: parseBoolean(canSelectGitlabManagedProvider),
      managedClusterPurchased: parseBoolean(managedClusterPurchased),
      trackingKey,
      namespaceFullPath,
      namespaceId,
      isProject,
      isGroup: parseBoolean(isGroup),
      namespaceName,
      collectorHost,
      dashboardEmptyStateIllustrationPath,
      analyticsSettingsPath,
      dashboardsPath: router.resolve('/').href,
      features: convertArrayToCamelCase(JSON.parse(features)),
      rootNamespaceName,
      rootNamespaceFullPath,
      dataSourceClickhouse: parseBoolean(dataSourceClickhouse),
      currentUserId: window.gon?.current_user_id,
      topicsExploreProjectsPath,
      isInstanceConfiguredWithSelfManagedAnalyticsProvider: parseBoolean(
        isInstanceConfiguredWithSelfManagedAnalyticsProvider,
      ),
      defaultUseInstanceConfiguration: parseBoolean(defaultUseInstanceConfiguration),
      overviewCountsAggregationEnabled: parseBoolean(overviewCountsAggregationEnabled),
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
    },
    render(h) {
      return h(DashboardsApp);
    },
  });
};
