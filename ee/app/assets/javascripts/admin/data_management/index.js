import Vue from 'vue';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';

export const initAdminDataManagementApp = () => {
  const el = document.getElementById('js-admin-data-management');

  if (!el) return null;

  return new Vue({
    el,
    render(createElement) {
      return createElement(AdminDataManagementApp);
    },
  });
};
