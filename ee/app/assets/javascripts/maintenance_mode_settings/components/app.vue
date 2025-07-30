<script>
import { GlForm, GlToggle, GlFormGroup, GlFormTextarea, GlButton, GlLoadingIcon } from '@gitlab/ui';
import { updateApplicationSettings } from '~/rest_api';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';

export default {
  name: 'MaintenanceModeSettingsApp',
  i18n: {
    toggleLabel: __('Enable maintenance mode'),
    toggleHelpText: __(
      'Non-admin users are restricted to read-only access, in both GitLab UI and API.',
    ),
    bannerMessagePlaceholder: __('GitLab is undergoing maintenance'),
    buttonText: __('Save changes'),
    bannerLabel: __('Banner message'),
  },
  components: {
    GlForm,
    GlToggle,
    GlFormGroup,
    GlFormTextarea,
    GlButton,
    GlLoadingIcon,
  },
  props: {
    initialBannerMessage: {
      type: String,
      required: false,
      default: '',
    },
    initialMaintenanceEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      bannerMessage: this.initialBannerMessage,
      isMaintenanceEnabled: this.initialMaintenanceEnabled,
    };
  },
  methods: {
    async updateMaintenanceModeSettings() {
      try {
        this.isLoading = true;

        const {
          data: {
            maintenance_mode: maintenanceMode,
            maintenance_mode_message: maintenanceModeMessage,
          },
        } = await updateApplicationSettings({
          maintenance_mode: this.isMaintenanceEnabled,
          maintenance_mode_message: this.bannerMessage,
        });

        this.isMaintenanceEnabled = Boolean(maintenanceMode);
        this.bannerMessage = maintenanceModeMessage || '';
      } catch {
        createAlert({
          message: s__('MaintenanceMode|There was an error updating the Maintenance Mode Settings'),
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
<template>
  <section>
    <gl-loading-icon v-if="isLoading" size="xl" />
    <gl-form v-else @submit.prevent="updateMaintenanceModeSettings">
      <div class="gl-mb-4 gl-flex gl-items-center">
        <gl-toggle
          v-model="isMaintenanceEnabled"
          :label="$options.i18n.toggleLabel"
          label-position="hidden"
        />
        <div class="gl-ml-3">
          <p class="gl-mb-0">{{ $options.i18n.toggleLabel }}</p>
          <p class="gl-mb-0 gl-text-subtle">
            {{ $options.i18n.toggleHelpText }}
          </p>
        </div>
      </div>
      <gl-form-group :label="$options.i18n.bannerLabel" label-for="maintenanceBannerMessage">
        <gl-form-textarea
          id="maintenanceBannerMessage"
          v-model="bannerMessage"
          :placeholder="$options.i18n.bannerMessagePlaceholder"
          no-resize
        />
      </gl-form-group>
      <gl-button variant="confirm" type="submit">{{ $options.i18n.buttonText }}</gl-button>
    </gl-form>
  </section>
</template>
