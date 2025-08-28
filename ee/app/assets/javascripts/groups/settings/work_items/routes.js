import ChangeLifecycle from './custom_status/change_lifecycle.vue';
import WorkItemSettingsHome from './work_item_settings_home.vue';

export const getRoutes = (fullPath) => {
  return [
    {
      path: '/',
      name: 'workItemSettingsHome',
      component: WorkItemSettingsHome,
      props: { fullPath },
    },
    {
      path: `/lifecycle/:workItemType`,
      name: 'changeLifecycle',
      component: ChangeLifecycle,
      props: { fullPath },
    },
  ];
};
