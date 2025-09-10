import Vue from 'vue';
import UsageBillingUserDashboardApp from 'ee/usage_quotas/usage_billing/users/show/components/app.vue';

/**
 * @param {HTMLElement} el
 */
export function initUsageBillingUserDashboard(el) {
  if (!el) {
    return null;
  }

  const { userId } = el.dataset;

  return new Vue({
    el,
    name: 'UsageBillingUserDashboardRoot',
    provide: { userId },
    render(createElement) {
      return createElement(UsageBillingUserDashboardApp);
    },
  });
}
