import ChangeLifecycleSteps from './custom_status/change_lifecycle/change_lifecycle_steps.vue';
import WorkItemSettingsHome from './work_item_settings_home.vue';

export const getRoutes = (fullPath) => {
  return [
    {
      path: '/',
      name: 'workItemSettingsHome',
      component: WorkItemSettingsHome,
      props: (route) => ({
        fullPath,
        isStatusSectionExpanded: Boolean(route.query.isStatusSectionExpanded),
      }),
    },
    {
      path: `/lifecycle/:workItemType`,
      name: 'changeLifecycle',
      component: ChangeLifecycleSteps,
      props: { fullPath },
    },
  ];
};
