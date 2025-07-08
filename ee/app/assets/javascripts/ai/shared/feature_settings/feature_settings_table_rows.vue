<script>
import { GlTableLite, GlSkeletonLoader, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectionBatchSettingsUpdater from 'ee/ai/model_selection/batch_settings_updater.vue';

const baseTdClasses = ['gl-content-center', '!gl-border-b-0', '!gl-bg-subtle'];

export default {
  name: 'FeatureSettingsTableRows',
  components: {
    GlTableLite,
    GlSkeletonLoader,
    ModelSelector,
    ModelSelectionBatchSettingsUpdater,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
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
      label: s__('AdminAIPoweredFeatures|Features'),
      thClass: 'gl-w-1/3',
      tdClass: baseTdClasses,
    },
    {
      key: 'model_name',
      label: s__('AdminAIPoweredFeatures|Model'),
      thClass: 'gl-w-1/3',
      tdClass: baseTdClasses,
    },
    {
      key: 'batch_model_update',
      label: s__('AdminAIPoweredFeatures|Apply to all sub-features'),
      thClass: 'gl-hidden gl-w-1/3',
      tdClass: baseTdClasses,
    },
  ],
  data() {
    return {
      batchUpdateIsSaving: false,
    };
  },
  methods: {
    updateBatchSavingState(state) {
      this.batchUpdateIsSaving = state;
    },
  },
  loaderItems: [
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
  ],
};
</script>
<template>
  <gl-table-lite
    class="gl-border gl-mb-0 gl-rounded-lg gl-border-section gl-bg-section"
    :fields="$options.fields"
    :items="isLoading ? $options.loaderItems : aiFeatureSettings"
    responsive
    borderless
  >
    <template #head(model_name)="{ label }">
      {{ label }}
      <gl-icon
        v-gl-tooltip="s__('AdminAIPoweredFeatures|Select the model for the feature')"
        variant="info"
        name="information-o"
      />
    </template>
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
        <rect y="8" x="0" :width="item.loaderWidth.modelName" height="24" rx="10" />
      </gl-skeleton-loader>
      <model-selector
        v-else
        class="gl-float-right gl-w-full gl-max-w-[440px]"
        :ai-feature-setting="item"
        :batch-update-is-saving="batchUpdateIsSaving"
      />
    </template>
    <template #cell(batch_model_update)="{ item }">
      <model-selection-batch-settings-updater
        v-if="!isLoading && aiFeatureSettings.length > 1"
        class="gl-float-right"
        :ai-feature-settings="aiFeatureSettings"
        :selected-feature-setting="item"
        @update-batch-saving-state="updateBatchSavingState"
      />
    </template>
  </gl-table-lite>
</template>
