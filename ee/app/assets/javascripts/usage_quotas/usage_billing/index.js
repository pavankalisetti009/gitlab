import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createApolloClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import UsageBillingDashboardPage from 'ee/usage_quotas/usage_billing/components/meta_app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingDashboard(el) {
  if (!el) {
    return null;
  }

  const {
    userUsagePath,
    isSaas,
    isFree,
    trialStartDate = undefined,
    trialEndDate = undefined,
    namespacePath,
    customersUsageDashboardPath,
    upgradeButtonPath,
  } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({ defaultClient: createApolloClient() });

  return new Vue({
    el,
    name: 'UsageBillingDashboardRoot',
    apolloProvider,
    provide: {
      userUsagePath,
      isSaas: parseBoolean(isSaas),
      isFree: parseBoolean(isFree),
      trialStartDate,
      trialEndDate,
      namespacePath,
      customersUsageDashboardPath,
      upgradeButtonPath,
    },
    render(createElement) {
      return createElement(UsageBillingDashboardPage);
    },
  });
}
