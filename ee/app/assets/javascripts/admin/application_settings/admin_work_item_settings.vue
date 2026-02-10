<script>
import WorkItemSettings from 'ee/groups/settings/work_items/work_item_settings_home.vue';
import { DEFAULT_SETTINGS_CONFIG } from 'ee/work_items/constants';

export default {
  name: 'AdminWorkItemSettings',
  components: {
    WorkItemSettings,
  },
  data() {
    return {
      viewConfig: {
        ...DEFAULT_SETTINGS_CONFIG,
        showCustomFieldsSettings: false,
        showCustomStatusSettings: false,
        context: 'admin', // 'root', 'admin', 'nested'
      },
    };
  },
};
</script>

<template>
  <work-item-settings :config="viewConfig" />
</template>
