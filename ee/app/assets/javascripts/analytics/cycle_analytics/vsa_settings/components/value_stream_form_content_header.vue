<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { i18n } from 'ee/analytics/cycle_analytics/components/create_value_stream_form/constants';

const { FORM_TITLE, EDIT_FORM_TITLE, EDIT_FORM_ACTION } = i18n;

export default {
  name: 'ValueStreamFormContentHeader',
  components: {
    GlButton,
  },
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    valueStreamPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  i18n: {
    newValueStream: FORM_TITLE,
    editValueStreamTitle: EDIT_FORM_TITLE,
    saveValueStreamAction: EDIT_FORM_ACTION,
    viewValueStreamAction: s__('ValueStreamAnalytics|View value stream'),
  },
  computed: {
    primaryButtonText() {
      return this.isEditing
        ? this.$options.i18n.saveValueStreamAction
        : this.$options.i18n.newValueStream;
    },
    formTitle() {
      return this.isEditing
        ? this.$options.i18n.editValueStreamTitle
        : this.$options.i18n.newValueStream;
    },
  },
};
</script>

<template>
  <header class="page-title gl-flex gl-flex-wrap gl-items-center gl-justify-between gl-gap-5">
    <h1 data-testid="value-stream-form-title" class="gl-my-0 gl-text-size-h-display">
      {{ formTitle }}
    </h1>
    <div class="gl-flex gl-w-full gl-flex-col gl-gap-3 sm:gl-w-auto sm:gl-flex-row">
      <gl-button
        v-if="isEditing"
        category="secondary"
        variant="confirm"
        :href="valueStreamPath"
        :disabled="isLoading"
        data-testid="view-value-stream"
        >{{ $options.i18n.viewValueStreamAction }}</gl-button
      >
      <gl-button
        data-testid="value-stream-form-primary-btn"
        variant="confirm"
        :loading="isLoading"
        @click="$emit('clickedPrimaryAction')"
        >{{ primaryButtonText }}</gl-button
      >
    </div>
  </header>
</template>
