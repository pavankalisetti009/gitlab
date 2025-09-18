import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import ProductAnalyticsOnboardingView from 'ee/product_analytics/onboarding/onboarding_view.vue';
import ProductAnalyticsOnboardingSetup from 'ee/product_analytics/onboarding/onboarding_setup.vue';
import DashboardsList from './components/dashboards_list.vue';
import AnalyticsDashboard from './components/analytics_dashboard.vue';
import { AI_IMPACT_DASHBOARD, AI_IMPACT_DASHBOARD_LEGACY } from './constants';

Vue.use(VueRouter);

export default (base, breadcrumbState, permissions = {}) => {
  return new VueRouter({
    mode: 'history',
    base,
    routes: [
      {
        name: 'index',
        path: '/',
        component: DashboardsList,
        meta: {
          getName: () => s__('Analytics|Analytics dashboards'),
          root: true,
        },
      },
      ...(permissions.canConfigureProjectSettings
        ? [
            {
              name: 'product-analytics-onboarding',
              path: '/product-analytics-onboarding',
              component: ProductAnalyticsOnboardingView,
              meta: {
                getName: () => s__('ProductAnalytics|Product analytics onboarding'),
              },
            },
            {
              name: 'instrumentation-detail',
              path: '/product-analytics-setup',
              component: ProductAnalyticsOnboardingSetup,
              meta: {
                getName: () => s__('ProductAnalytics|Product analytics onboarding'),
              },
            },
          ]
        : []),
      {
        name: 'ai-impact-legacy-redirect',
        path: `/${AI_IMPACT_DASHBOARD_LEGACY}`,
        redirect: `/${AI_IMPACT_DASHBOARD}`,
      },
      {
        name: 'dashboard-detail',
        path: '/:slug',
        component: AnalyticsDashboard,
        meta: {
          getName: () => breadcrumbState.name,
        },
      },
    ],
  });
};
