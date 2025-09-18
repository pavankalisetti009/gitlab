import Vue from 'vue';
import AdminUsageDashboard from 'ee/usage_quotas/usage_billing/components/app.vue';

function initAdminUsageDashboard() {
  const el = document.getElementById('js-instance-usage-billing-dashboard');

  if (!el) {
    return null;
  }

  const { userUsagePath } = el.dataset;

  return new Vue({
    el,
    name: 'AdminUsageBillingDashboardApp',
    provide: {
      // TODO: this property should be replaced with a value provided from the backend
      purchaseCommitmentUrl: '/admin/gitlab_duo/usage',
      userUsagePath,
    },
    render(createElement) {
      return createElement(AdminUsageDashboard);
    },
  });
}

initAdminUsageDashboard();
