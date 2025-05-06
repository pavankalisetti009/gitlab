<script>
import { GlButton } from '@gitlab/ui';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';

export default {
  name: 'ValueStreamFormContentActions',
  components: {
    GlButton,
  },
  inject: ['vsaPath', 'valueStream', 'isEditing'],
  props: {
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    primaryButtonText() {
      return this.isEditing
        ? s__('CreateValueStreamForm|Save value stream')
        : s__('CreateValueStreamForm|New value stream');
    },
    cancelHref() {
      return this.isEditing && this.valueStream?.id > 0
        ? mergeUrlParams({ value_stream_id: this.valueStream.id }, this.vsaPath)
        : this.vsaPath;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-3 sm:gl-w-auto sm:gl-flex-row">
    <gl-button
      data-testid="primary-button"
      variant="confirm"
      :loading="isLoading"
      @click="$emit('clickPrimaryAction')"
      >{{ primaryButtonText }}</gl-button
    >
    <gl-button data-testid="cancel-button" :href="cancelHref" :disabled="isLoading">{{
      __('Cancel')
    }}</gl-button>
  </div>
</template>
