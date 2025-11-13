import Vue from 'vue';
import AdminDataManagementItemApp from 'ee/admin/data_management_item/components/app.vue';

export const initAdminDataManagementItem = () => {
  const el = document.getElementById('js-admin-data-management-item');

  if (!el) return null;

  return new Vue({
    el,
    render(createElement) {
      return createElement(AdminDataManagementItemApp);
    },
  });
};
