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
  inject: ['valueStream', 'defaultStages'],
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['stages', 'isFetchingGroupStages', 'isLoading']),
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
};
</script>
<template>
  <div>
    <div v-if="isLoading || isFetchingGroupStages" class="gl-pt-7 gl-text-center">
      <gl-loading-icon size="lg" />
    </div>
    <value-stream-form-content v-else :initial-data="initialData" :is-editing="isEditing" />
  </div>
</template>
