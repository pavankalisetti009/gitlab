<script>
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';
import CodeSuggestionsConnectionForm from '../components/code_suggestions_connection_form.vue';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
    CodeSuggestionsConnectionForm,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: ['disabledDirectConnectionMethod'],
  props: {
    redirectPath: {
      type: String,
      required: true,
    },
    duoProVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      disabledConnection: this.disabledDirectConnectionMethod,
    };
  },
  computed: {
    hasFormChanged() {
      return this.disabledConnection !== this.disabledDirectConnectionMethod;
    },
  },
  methods: {
    async updateSettings({ duoAvailability, experimentFeaturesEnabled }) {
      try {
        this.isLoading = true;

        await updateApplicationSettings({
          duo_availability: duoAvailability,
          instance_level_ai_beta_features_enabled: experimentFeaturesEnabled,
          disabled_direct_code_suggestions: this.disabledConnection,
        });

        visitUrlWithAlerts(this.redirectPath, [
          {
            id: 'application-settings-successfully-updated',
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
    onConnectionFormChange(value) {
      this.disabledConnection = value;
    },
  },
};
</script>
<template>
  <ai-common-settings :has-parent-form-changed="hasFormChanged" @submit="updateSettings">
    <template #ai-common-settings-bottom>
      <code-suggestions-connection-form v-if="duoProVisible" @change="onConnectionFormChange" />
    </template>
  </ai-common-settings>
</template>
