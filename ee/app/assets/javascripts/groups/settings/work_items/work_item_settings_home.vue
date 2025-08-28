<script>
import CustomFieldsList from './custom_fields/custom_fields_list.vue';
import CustomStatusSettings from './custom_status/custom_status_settings.vue';

export default {
  components: {
    CustomFieldsList,
    CustomStatusSettings,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <h1 class="settings-title gl-heading-1 gl-mb-1">
      {{ __('Issues') }}
    </h1>
    <p class="gl-text-subtle">
      {{
        s__(
          'WorkItem|Configure work items such as epics, issues, and tasks to represent how your team works.',
        )
      }}
    </p>
    <custom-status-settings :full-path="fullPath" />
    <custom-fields-list :full-path="fullPath" />
  </div>
</template>
