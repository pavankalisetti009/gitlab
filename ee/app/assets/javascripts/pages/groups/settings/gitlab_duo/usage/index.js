import Vue from 'vue';
import GroupUsageDashboard from 'ee/usage_quotas/usage_billing/components/app.vue';

function initGroupUsageDashboard() {
  const el = document.getElementById('js-group-usage-billing-dashboard');

  if (!el) {
    return null;
  }

  const { purchaseCommitmentUrl, userUsagePath } = el.dataset;

  return new Vue({
    el,
    name: 'GroupUsageBillingDashboardApp',
    provide: {
      purchaseCommitmentUrl,
      userUsagePath,
    },
    render(createElement) {
      return createElement(GroupUsageDashboard);
    },
  });
}

initGroupUsageDashboard();
