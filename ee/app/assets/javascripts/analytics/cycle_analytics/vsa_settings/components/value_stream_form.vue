<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { generateInitialStageData } from '../utils';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'ValueStreamForm',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
  },
  inject: ['valueStream'],
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['stages', 'defaultStageConfig', 'isFetchingGroupStages', 'isLoading']),
    isLoadingOrFetching() {
      return this.isLoading || this.isFetchingGroupStages;
    },
    initialData() {
      return this.isEditing
        ? {
            ...this.valueStream,
            stages: generateInitialStageData(this.defaultStageConfig, this.stages),
          }
        : {
            name: '',
            stages: [],
          };
    },
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
