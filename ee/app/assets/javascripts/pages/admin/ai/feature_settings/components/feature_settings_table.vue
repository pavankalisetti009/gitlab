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
    :items="featureSettings"
    stacked="md"
    :hover="true"
    :selectable="false"
  >
    <template #cell(main_feature)="{ item }">
      {{ item.mainFeature }}
    </template>
    <template #cell(sub_feature)="{ item }">
      {{ item.title }}
    </template>
    <template #cell(model_name)="{ item }">
      <model-select-dropdown
        :feature-setting="item"
        :models="models"
        :new-self-hosted-model-path="newSelfHostedModelPath"
      />
    </template>
  </gl-table-lite>
</template>
