<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { generateInitialStageData } from '../utils';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'ValueStreamForm',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
  },
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState([
      'selectedValueStream',
      'stages',
      'defaultStageConfig',
      'defaultGroupLabels',
      'isFetchingGroupStagesAndEvents',
      'isFetchingGroupLabels',
      'isLoading',
    ]),
    isLoadingOrFetching() {
      return this.isLoading || this.isFetchingGroupLabels || this.isFetchingGroupStagesAndEvents;
    },
    initialData() {
      return this.isEditing
        ? {
            ...this.selectedValueStream,
            stages: generateInitialStageData(this.defaultStageConfig, this.stages),
          }
        : {
            name: '',
            stages: [],
          };
    },
  },
  created() {
    if (!this.defaultGroupLabels) {
      this.fetchGroupLabels();
    }
  },
  methods: {
    ...mapActions(['fetchGroupLabels']),
  },
};
</script>
<template>
  <div>
    <div v-if="isLoadingOrFetching" class="gl-pt-7 gl-text-center">
      <gl-loading-icon size="lg" />
    </div>
    <value-stream-form-content
      v-else
      :initial-data="initialData"
      :default-stage-config="defaultStageConfig"
      :is-editing="isEditing"
    />
  </div>
</template>
