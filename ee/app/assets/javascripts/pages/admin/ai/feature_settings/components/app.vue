<script>
import stubbedAiFeatureSettings from '../data_stub';
import AiFeatureSettingsTable from './feature_settings_table.vue';

export default {
  name: 'FeatureSettingsApp',
  components: {
    AiFeatureSettingsTable,
  },
  props: {
    // Return stubbed data for now
    featureSettings: {
      type: Array,
      required: false,
      default: () => {
        return stubbedAiFeatureSettings;
      },
    },
  },
};
</script>
<template>
  <div>
    <section>
      <h1 class="page-title gl-text-size-h-display">
        {{ s__('AdminAIPoweredFeatures|AI-powered features') }}
      </h1>
      <div class="gl-items-top gl-flex gl-justify-between">
        <p>
          {{
            s__(
              'AdminAIPoweredFeatures|Features that can be enabled, disabled, or linked to a cloud-based or self-hosted model.',
            )
          }}
        </p>
      </div>
    </section>
    <ai-feature-settings-table :feature-settings="featureSettings" />
  </div>
</template>
