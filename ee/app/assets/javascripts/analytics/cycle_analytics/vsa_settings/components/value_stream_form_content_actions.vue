<script>
import { GlButton } from '@gitlab/ui';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { i18n } from '../constants';

const { FORM_TITLE, EDIT_FORM_ACTION, BTN_ADD_STAGE } = i18n;

export default {
  name: 'ValueStreamFormContentActions',
  components: {
    GlButton,
  },
  inject: ['vsaPath', 'valueStream'],
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
  },
  i18n: {
    newValueStreamAction: FORM_TITLE,
    saveValueStreamAction: EDIT_FORM_ACTION,
    addStageAction: BTN_ADD_STAGE,
    cancelAction: __('Cancel'),
  },
  computed: {
    primaryButtonText() {
      return this.isEditing
        ? this.$options.i18n.saveValueStreamAction
        : this.$options.i18n.newValueStreamAction;
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
      $options.i18n.cancelAction
    }}</gl-button>
  </div>
</template>
