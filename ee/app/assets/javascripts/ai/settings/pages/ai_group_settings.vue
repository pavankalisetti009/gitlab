<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    areDuoSettingsLocked: {
      type: Boolean,
      required: true,
    },
    redirectPath: {
      type: String,
      required: true,
    },
    updateId: {
      type: String,
      required: true,
    },
  },
  data: () => ({ isLoading: false }),
  methods: {
    async updateSettings({ duoAvailability }) {
      try {
        this.isLoading = true;

        await updateGroupSettings(this.updateId, {
          duo_availability: duoAvailability,
        });

        visitUrlWithAlerts(this.redirectPath, [
          {
            id: 'organization-group-successfully-updated',
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
  <ai-common-settings
    :duo-availability="duoAvailability"
    :are-duo-settings-locked="areDuoSettingsLocked"
    @submit="updateSettings"
  />
</template>
