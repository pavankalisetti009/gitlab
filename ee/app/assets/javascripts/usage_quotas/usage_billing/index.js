import Vue from 'vue';
import UsageBillingDashboardPage from 'ee/usage_quotas/usage_billing/components/app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingDashboard(el) {
  if (!el) {
    return null;
  }

  const { purchaseCommitmentUrl, userUsagePath, fetchUsageDataApiUrl } = el.dataset;

  return new Vue({
    el,
    name: 'UsageBillingDashboardRoot',
    provide: { purchaseCommitmentUrl, userUsagePath, fetchUsageDataApiUrl },
    render(createElement) {
      return createElement(UsageBillingDashboardPage);
    },
  });
}
