<script>
import { updateApplicationSettings } from '~/rest_api';
import axios from '~/lib/utils/axios_utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';
import CodeSuggestionsConnectionForm from '../components/code_suggestions_connection_form.vue';
import AiModelsForm from '../components/ai_models_form.vue';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
    AiModelsForm,
    CodeSuggestionsConnectionForm,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: ['disabledDirectConnectionMethod', 'betaSelfHostedModelsEnabled', 'toggleBetaModelsPath'],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
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
      aiModelsEnabled: this.betaSelfHostedModelsEnabled,
    };
  },
  computed: {
    hasFormChanged() {
      return (
        this.disabledConnection !== this.disabledDirectConnectionMethod ||
        this.hasAiModelsFormChanged
      );
    },
    hasAiModelsFormChanged() {
      return this.aiModelsEnabled !== this.betaSelfHostedModelsEnabled;
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

        if (this.hasAiModelsFormChanged) {
          await this.updateAiModelsSetting();
        }

        visitUrlWithAlerts(this.redirectPath, [
          {
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        this.onError(error);
      } finally {
        this.isLoading = false;
      }
    },
    async updateAiModelsSetting() {
      await axios
        .post(this.toggleBetaModelsPath)
        .catch((error) => {
          this.onError(error);
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
    onConnectionFormChange(value) {
      this.disabledConnection = value;
    },
    onAiModelsFormChange(value) {
      this.aiModelsEnabled = value;
    },
    onError(error) {
      createAlert({
        message: this.$options.i18n.errorMessage,
        captureError: true,
        error,
      });
    },
  },
};
</script>
<template>
  <ai-common-settings
    :is-group="false"
    :has-parent-form-changed="hasFormChanged"
    @submit="updateSettings"
  >
    <template #ai-common-settings-bottom>
      <code-suggestions-connection-form v-if="duoProVisible" @change="onConnectionFormChange" />
      <ai-models-form v-if="duoProVisible" @change="onAiModelsFormChange" />
    </template>
  </ai-common-settings>
</template>
