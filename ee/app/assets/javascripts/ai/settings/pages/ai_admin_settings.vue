<script>
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  props: {
    redirectPath: {
      type: String,
      required: true,
    },
  },
  data: () => ({ isLoading: false }),
  methods: {
    async updateSettings({ duoAvailability, experimentFeaturesEnabled }) {
      try {
        this.isLoading = true;

        await updateApplicationSettings({
          duo_availability: duoAvailability,
          instance_level_ai_beta_features_enabled: experimentFeaturesEnabled,
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
  },
};
</script>
<template>
  <ai-common-settings @submit="updateSettings" />
</template>
