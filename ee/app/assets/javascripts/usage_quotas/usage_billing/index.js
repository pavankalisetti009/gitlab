import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createApolloClient from '~/lib/graphql';
import UsageBillingDashboardPage from 'ee/usage_quotas/usage_billing/components/app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingDashboard(el) {
  if (!el) {
    return null;
  }

  const { userUsagePath, fetchUsageDataApiUrl, namespacePath } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({ defaultClient: createApolloClient() });

  return new Vue({
    el,
    name: 'UsageBillingDashboardRoot',
    apolloProvider,
    provide: { userUsagePath, fetchUsageDataApiUrl, namespacePath },
    render(createElement) {
      return createElement(UsageBillingDashboardPage);
    },
  });
}
