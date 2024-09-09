<script>
import { GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';
import ModelSelectDropdown from './model_select_dropdown.vue';

export default {
  name: 'FeatureSettingsTable',
  components: {
    GlTableLite,
    ModelSelectDropdown,
  },
  props: {
    featureSettings: {
      type: Array,
      required: true,
    },
    newSelfHostedModelPath: {
      type: String,
      required: true,
    },
    models: {
      type: Array,
      required: true,
    },
  },
  computed: {
    formattedFeatureSettings() {
      return this.featureSettings.flatMap((feature) =>
        feature.subFeatures.map((subFeature) => ({
          feature: feature.name,
          subFeature: subFeature.name,
        })),
      );
    },
  },
  fields: [
    {
      key: 'main_feature',
      label: s__('AdminAIPoweredFeatures|Main feature'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
    {
      key: 'sub_feature',
      label: s__('AdminAIPoweredFeatures|Sub feature'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model_name',
      label: s__('AdminAIPoweredFeatures|Model name'),
      thClass: 'w-15p',
      tdClass: 'gl-content-center',
    },
  ],
};
</script>
<template>
  <gl-table-lite
    :fields="$options.fields"
    :items="formattedFeatureSettings"
    stacked="md"
    :hover="true"
    :selectable="false"
  >
    <template #cell(main_feature)="{ item }">
      {{ item.feature }}
    </template>
    <template #cell(sub_feature)="{ item }">
      {{ item.subFeature }}
    </template>
    <template #cell(model_name)>
      <model-select-dropdown
        :models="models"
        :new-self-hosted-model-path="newSelfHostedModelPath"
      />
    </template>
  </gl-table-lite>
</template>
