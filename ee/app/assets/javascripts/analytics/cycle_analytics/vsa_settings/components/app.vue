<script>
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { I18N_VSA_ERROR_STAGES } from '~/analytics/cycle_analytics/constants';
import { s__ } from '~/locale';
import { getStagesAndEvents } from 'ee/api/analytics_api';
import { transformRawStages } from '../../utils';
import { generateInitialStageData } from '../utils';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'VSASettingsApp',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
    GlAlert,
  },
  inject: ['isEditing', 'valueStream', 'defaultStages', 'namespaceFullPath'],
  data() {
    return {
      isLoading: false,
      showError: false,
      stages: [],
    };
  },
  computed: {
    pageHeader() {
      return this.isEditing
        ? s__('CreateValueStreamForm|Edit value stream')
        : s__('CreateValueStreamForm|New value stream');
    },
    initialData() {
      return this.isEditing
        ? {
            ...this.valueStream,
            stages: generateInitialStageData(this.defaultStages, this.stages),
          }
        : {
            name: '',
            stages: [],
          };
    },
  },
  created() {
    if (this.isEditing) {
      this.fetchStages();
    }
  },
  methods: {
    async fetchStages() {
      this.isLoading = true;

      try {
        const {
          data: { stages = [] },
        } = await getStagesAndEvents({
          namespacePath: this.namespaceFullPath,
          valueStreamId: this.valueStream.id,
        });

        this.stages = transformRawStages(stages);
      } catch {
        this.showError = true;
      } finally {
        this.isLoading = false;
      }
    },
  },
  I18N_VSA_ERROR_STAGES,
};
</script>
<template>
  <div>
    <h1 data-testid="vsa-settings-page-header" class="page-title gl-text-size-h-display">
      {{ pageHeader }}
    </h1>
    <gl-loading-icon v-if="isLoading" class="gl-pt-7" size="lg" />
    <gl-alert v-else-if="showError" variant="danger" :dismissible="false">
      {{ $options.I18N_VSA_ERROR_STAGES }}
    </gl-alert>
    <value-stream-form-content v-else :initial-data="initialData" />
  </div>
</template>
