export const DEFAULT_SETTINGS_CONFIG = {
  showWorkItemTypesSettings: true,
  showCustomFieldsSettings: true,
  showCustomStatusSettings: true,
  workItemTypeSettingsPermissions: ['edit', 'create', 'archive', 'list'], // 'read' is default hence showing custom work item types
  // in future we may also have similar permissions on custom status and custom fields
  // customStatusSettingsPermissions: ['createLifecycle', 'editLifecycle']
  // we may allow editing lifecycle even at subgroup level that may change
  layout: 'list', // 'table'
};

export const STATUS_SECTION_ID = 'js-custom-status-settings';
export const CUSTOM_FIELD_SECTION_ID = 'js-custom-fields-settings';
export const WORK_ITEM_TYPES_SECTION_ID = 'js-work-item-types-settings';
