<script>
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import CustomFieldsList from './custom_fields/custom_fields_list.vue';
import CustomStatusSettings from './custom_status/custom_status_settings.vue';

export default {
  components: {
    CustomFieldsList,
    CustomStatusSettings,
  },
  mixins: [glFeatureFlagMixin()],
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
    <custom-status-settings :full-path="fullPath" />
    <custom-fields-list :full-path="fullPath" />
  </div>
</template>
