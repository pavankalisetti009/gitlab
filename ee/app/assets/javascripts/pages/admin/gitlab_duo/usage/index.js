import Vue from 'vue';
import AdminUsageDashboard from 'ee/usage_quotas/usage_billing/components/app.vue';

function initAdminUsageDashboard() {
  const el = document.getElementById('js-instance-usage-billing-dashboard');

  if (!el) {
    return null;
  }

  const { purchaseCommitmentUrl, userUsagePath, fetchUsageDataApiUrl } = el.dataset;

  return new Vue({
    el,
    name: 'AdminUsageBillingDashboardApp',
    provide: {
      userUsagePath,
      purchaseCommitmentUrl,
      fetchUsageDataApiUrl,
    },
    render(createElement) {
      return createElement(AdminUsageDashboard);
    },
  });
}

initAdminUsageDashboard();
