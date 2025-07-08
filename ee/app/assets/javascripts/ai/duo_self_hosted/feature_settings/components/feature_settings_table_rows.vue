<script>
import { GlExperimentBadge, GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { RELEASE_STATES } from '../../constants';
import ModelSelector from './model_selector.vue';
import BatchSettingsUpdater from './batch_settings_updater.vue';

export default {
  name: 'FeatureSettingsTableRows',
  components: {
    GlExperimentBadge,
    GlSkeletonLoader,
    GlTableLite,
    BatchSettingsUpdater,
    ModelSelector,
  },
  i18n: {
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
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
      batchUpdateIsSaving: false,
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
  methods: {
    isBetaFeature(releaseState) {
      return releaseState === RELEASE_STATES.BETA;
    },
    isExperimentFeature(releaseState) {
      return releaseState === RELEASE_STATES.EXPERIMENT;
    },
    updateBatchSavingState(state) {
      this.batchUpdateIsSaving = state;
    },
  },
};
</script>
<template>
  <gl-table-lite
    thead-class="gl-hidden"
    class="gl-mb-0"
    :fields="$options.fields"
    :items="isLoading ? loaderItems : aiFeatureSettings"
    stacked="md"
    fixed
  >
    <template #cell(sub_feature)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="38" :width="600">
        <rect y="8" :width="item.loaderWidth.subFeature" height="24" rx="10" />
      </gl-skeleton-loader>
      <div v-else>
        <gl-experiment-badge
          v-if="isBetaFeature(item.releaseState)"
          class="gl-ml-0 gl-mr-3"
          data-testid="feature-beta-badge"
          type="beta"
        />
        <gl-experiment-badge
          v-if="isExperimentFeature(item.releaseState)"
          class="gl-ml-0 gl-mr-3"
          data-testid="feature-experiment-badge"
          type="experiment"
        />
        <span>{{ item.title }}</span>
      </div>
    </template>
    <template #cell(model_name)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :height="38" :width="600">
        <rect y="8" x="155" :width="item.loaderWidth.modelName" height="24" rx="10" />
      </gl-skeleton-loader>
      <model-selector
        v-else
        :batch-update-is-saving="batchUpdateIsSaving"
        class="gl-float-right gl-w-full gl-max-w-[440px]"
        :ai-feature-setting="item"
      />
    </template>
    <template #cell(batch_model_update)="{ item }">
      <batch-settings-updater
        v-if="!isLoading && aiFeatureSettings.length > 1"
        class="gl-float-right"
        :ai-feature-settings="aiFeatureSettings"
        :selected-feature-setting="item"
        @update-batch-saving-state="updateBatchSavingState"
      />
    </template>
  </gl-table-lite>
</template>
