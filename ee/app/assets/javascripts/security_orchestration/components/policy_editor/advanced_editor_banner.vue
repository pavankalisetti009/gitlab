<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { __, s__ } from '~/locale';
import { ADVANCED_EDITOR_DISMISS_STORAGE_KEY } from './constants';

export default {
  BANNER_STORAGE_KEY: ADVANCED_EDITOR_DISMISS_STORAGE_KEY,
  i18n: {
    bannerContent: s__(
      'SecurityOrchestration|%{boldStart}Experiment:%{boldEnd} Try our new advanced policy editor for a more intuitive experience.',
    ),
    primaryButtonText: s__('SecurityOrchestration|Try advanced editor'),
    secondaryButtonText: __("Don't show again"),
    title: __('Experimental'),
    label: __('Advanced editor'),
  },
  name: 'AdvancedEditorBanner',
  components: {
    LocalStorageSync,
    GlAlert,
    GlSprintf,
  },
  data() {
    return {
      alertDismissed: false,
    };
  },
  methods: {
    dismissBanner() {
      this.alertDismissed = true;
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <!-- eslint-disable vue/v-on-event-hyphenation -->
    <gl-alert
      v-if="!alertDismissed"
      :secondary-button-text="$options.i18n.secondaryButtonText"
      variant="tip"
      @dismiss="dismissBanner"
      @secondaryAction="dismissBanner"
    >
      <!-- eslint-enable vue/v-on-event-hyphenation -->
      <gl-sprintf :message="$options.i18n.bannerContent">
        <template #bold="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>
  </local-storage-sync>
</template>
