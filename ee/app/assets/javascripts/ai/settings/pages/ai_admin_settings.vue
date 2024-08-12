<script>
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import { ERROR_MESSAGE } from '../constants';
import AiCommonSettings from '../components/ai_common_settings.vue';

export default {
  name: 'AiAdminSettings',
  components: {
    AiCommonSettings,
  },
  i18n: {
    successMessage: __('Application settings saved successfully.'),
    errorMessage: ERROR_MESSAGE,
  },
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    redirectPath: {
      type: String,
      required: true,
    },
  },
  data: () => ({ isLoading: false }),
  methods: {
    async updateSettings({ duoAvailability }) {
      try {
        this.isLoading = true;

        await updateApplicationSettings({
          duo_availability: duoAvailability,
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
  <ai-common-settings :duo-availability="duoAvailability" @submit="updateSettings" />
</template>
