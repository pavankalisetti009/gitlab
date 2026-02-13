import { DEFAULT_SETTINGS_CONFIG } from 'ee/work_items/constants';
import ChangeLifecycleSteps from './custom_status/change_lifecycle/change_lifecycle_steps.vue';
import WorkItemSettingsHome from './work_item_settings_home.vue';

export const getRoutes = (fullPath, isRootGroup) => {
  const subGroupWorkItemSettingsConfig = {
    ...DEFAULT_SETTINGS_CONFIG,
    showWorkItemTypesSettings: true,
    showCustomFieldsSettings: false,
    showCustomStatusSettings: false,
    workItemSettingsLayout: 'availability',
  };
  return [
    {
      path: '/',
      name: 'workItemSettingsHome',
      component: WorkItemSettingsHome,
      props: {
        fullPath,
        config: isRootGroup ? DEFAULT_SETTINGS_CONFIG : subGroupWorkItemSettingsConfig,
      },
    },
    {
      path: `/lifecycle/:workItemType`,
      name: 'changeLifecycle',
      component: ChangeLifecycleSteps,
      props: { fullPath },
    },
  ];
};
