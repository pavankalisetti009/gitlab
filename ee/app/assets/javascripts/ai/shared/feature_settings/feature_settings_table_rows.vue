<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';

export default {
  name: 'FeatureSettingsTableRows',
  components: {
    GlTableLite,
    GlSkeletonLoader,
    ModelSelector,
  },
  props: {
    aiFeatureSettings: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  fields: [
    {
      key: 'sub_feature',
      label: s__('AdminAIPoweredFeatures|Feature'), // for mobile only
      thClass: 'gl-w-1/2',
      tdClass: 'gl-content-center',
    },
    {
      key: 'model_name',
      label: s__('AdminAIPoweredFeatures|Model'), // for mobile only
      thClass: 'gl-w-1/2',
      tdClass: 'gl-content-center',
    },
    {
      key: 'batch_model_update',
      label: s__('AdminAIPoweredFeatures|Apply to all sub-features'), // for mobile only
      thClass: 'gl-w-1/2',
      tdClass: 'gl-content-center',
    },
  ],
  data() {
    return {
      featureSettings: this.aiFeatureSettings,
    };
  },
  computed: {
    loaderItems() {
      return [
        {
          loaderWidth: {
            subFeature: '200',
            modelName: '440',
          },
        },
        {
          loaderWidth: {
            subFeature: '80',
            modelName: '440',
          },
        },
        {
          loaderWidth: {
            subFeature: '150',
            modelName: '440',
          },
        },
      ];
    },
  },
  watch: {
    aiFeatureSettings: {
      handler(newValue) {
        this.featureSettings = newValue;
      },
    },
  },
};
</script>
<template>
  <gl-table-lite
    thead-class="gl-hidden"
    class="gl-mb-0"
    :fields="$options.fields"
    :items="isLoading ? loaderItems : featureSettings"
    stacked="md"
    fixed
  >
    <template #cell(sub_feature)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="38" :width="600">
        <rect y="8" :width="item.loaderWidth.subFeature" height="24" rx="10" />
      </gl-skeleton-loader>
      <div v-else>
        <span>{{ item.title }}</span>
      </div>
    </template>
    <template #cell(model_name)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="38" :width="600">
        <rect y="8" x="155" :width="item.loaderWidth.modelName" height="24" rx="10" />
      </gl-skeleton-loader>
      <model-selector
        v-else
        class="gl-float-right gl-w-full gl-max-w-[440px]"
        :ai-feature-setting="item"
      />
    </template>
  </gl-table-lite>
</template>
