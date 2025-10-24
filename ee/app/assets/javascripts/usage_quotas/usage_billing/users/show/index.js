import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createApolloClient from '~/lib/graphql';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingUserDashboard(el) {
  if (!el) {
    return null;
  }

  // NOTE: namespacePath is only provided on SaaS for group usage billing dashboard page
  const { username, namespacePath } = el.dataset;

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({ defaultClient: createApolloClient() });

  return new Vue({
    el,
    name: 'UsageBillingUserDashboardRoot',
    apolloProvider,
    provide: { username, namespacePath },
    render(createElement) {
      return createElement(UsageBillingUserDashboardApp);
    },
  });
}
