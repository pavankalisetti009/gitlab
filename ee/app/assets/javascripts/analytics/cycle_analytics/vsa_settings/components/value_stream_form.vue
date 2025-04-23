<script>
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { I18N_VSA_ERROR_STAGES } from '~/analytics/cycle_analytics/constants';
import { getStagesAndEvents } from 'ee/api/analytics_api';
import { transformRawStages } from '../../utils';
import { generateInitialStageData } from '../utils';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'ValueStreamForm',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
    GlAlert,
  },
  inject: ['valueStream', 'defaultStages', 'namespaceFullPath'],
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      showError: false,
      stages: [],
    };
  },
  computed: {
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
  mounted() {
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
      }

      this.isLoading = false;
    },
  },
  I18N_VSA_ERROR_STAGES,
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isLoading" class="gl-pt-7" size="lg" />
    <gl-alert v-else-if="showError" variant="danger" :dismissible="false">
      {{ $options.I18N_VSA_ERROR_STAGES }}
    </gl-alert>
    <value-stream-form-content v-else :initial-data="initialData" :is-editing="isEditing" />
  </div>
</template>
