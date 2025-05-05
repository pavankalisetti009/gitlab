<script>
import { GlCard, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { DUO_CORE, DUO_IDENTIFIERS, DUO_TITLES } from 'ee/usage_quotas/code_suggestions/constants';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoConfigurationSettingsRow from './duo_configuration_settings_row.vue';

export default {
  name: 'DuoConfigurationSettingsInfoCard',
  i18n: {
    aiLogsText: s__('AiPowered|AI logs'),
    aiGatewayUrlText: s__('AiPowered|Local AI gateway URL'),
    duoChangeConfigurationButtonText: s__('AiPowered|Change configuration'),
    experimentAndBetaFeaturesText: s__('AiPowered|Experiment and beta features'),
    betaSelfHostedModelsText: s__('AiPowered|Self-hosted beta models and features'),
    directConnectionsText: s__('AiPowered|Direct connections'),
    enabledText: __('Enabled'),
    defaultOnText: s__('AiPowered|On by default'),
    defaultOffText: s__('AiPowered|Off by default'),
    alwaysOffText: s__('AiPowered|Always off'),
    enabled: s__('AiPowered|Enabled'),
    disabled: s__('AiPowered|Not enabled'),
    duoCoreAvailabilityText: s__('AiPowered|GitLab Duo Core available to all users'),
  },
  components: {
    GlCard,
    GlButton,
    DuoConfigurationSettingsRow,
  },
  inject: {
    aiGatewayUrl: { default: '' },
    canManageSelfHostedModels: { default: false },
    duoConfigurationPath: {},
    isSaaS: {},
    duoAvailability: {},
    directCodeSuggestionsEnabled: { default: false },
    expandedLoggingEnabled: { default: false },
    experimentFeaturesEnabled: {},
    betaSelfHostedModelsEnabled: { default: false },
    areExperimentSettingsAllowed: {},
    areDuoCoreFeaturesEnabled: { default: false },
    isDuoBaseAccessAllowed: { default: false },
  },
  props: {
    duoTier: {
      type: String,
      required: true,
      validator: (val) => DUO_IDENTIFIERS.includes(val),
    },
  },
  computed: {
    isDuoCoreTier() {
      return this.duoTier === DUO_CORE;
    },
    onSelfManaged() {
      return !this.isSaaS;
    },
    getAvailabilityStatus() {
      switch (this.duoAvailability) {
        case AVAILABILITY_OPTIONS.DEFAULT_ON:
          return this.$options.i18n.defaultOnText;
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return this.$options.i18n.defaultOffText;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return this.$options.i18n.alwaysOffText;
        default:
          return null;
      }
    },
    activationStatus() {
      if (this.areDuoCoreFeaturesEnabled) {
        return this.$options.i18n.enabled;
      }

      return this.$options.i18n.disabled;
    },
    title() {
      return DUO_TITLES[this.duoTier];
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
    class="gl-justify-between"
  >
    <template #default>
      <section class="gl-flex gl-flex-col">
        <h2 class="gl-m-0 gl-text-lg" data-testid="duo-configuration-settings-info">
          {{ title }}
        </h2>
        <p v-if="isDuoCoreTier" class="gl-mb-3 gl-text-size-h-display gl-font-bold">
          <span data-testid="configuration-status">{{ activationStatus }}</span>
        </p>
        <p v-else class="gl-mb-3 gl-text-size-h-display gl-font-bold">
          <span data-testid="configuration-status">{{ getAvailabilityStatus }}</span>
        </p>
      </section>
      <section v-if="isDuoBaseAccessAllowed && !isDuoCoreTier">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.duoCoreAvailabilityText"
          :config-value="areDuoCoreFeaturesEnabled"
        />
      </section>
      <section v-if="areExperimentSettingsAllowed">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.experimentAndBetaFeaturesText"
          :config-value="experimentFeaturesEnabled"
        />
      </section>
      <section v-if="onSelfManaged">
        <duo-configuration-settings-row
          :duo-configuration-settings-row-type-title="$options.i18n.directConnectionsText"
          :config-value="directCodeSuggestionsEnabled"
        />
        <template v-if="canManageSelfHostedModels">
          <duo-configuration-settings-row
            :duo-configuration-settings-row-type-title="$options.i18n.betaSelfHostedModelsText"
            :config-value="betaSelfHostedModelsEnabled"
          />
          <duo-configuration-settings-row
            :duo-configuration-settings-row-type-title="$options.i18n.aiLogsText"
            :config-value="expandedLoggingEnabled"
          />
          <template v-if="aiGatewayUrl">
            <duo-configuration-settings-row
              :duo-configuration-settings-row-type-title="$options.i18n.aiGatewayUrlText"
              :config-value="aiGatewayUrl"
            />
          </template>
        </template>
      </section>
    </template>
    <template #footer>
      <div data-testid="duo-configuration-settings-action-buttons">
        <gl-button category="primary" variant="default" :href="duoConfigurationPath">{{
          $options.i18n.duoChangeConfigurationButtonText
        }}</gl-button>
      </div>
    </template>
  </gl-card>
</template>
