<script>
import { GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from './duo_core_features_form.vue';
import DuoPromptCache from './duo_prompt_cache_form.vue';
import DuoFlowSettings from './duo_flow_settings.vue';
import DuoSastFpDetectionSettings from './duo_sast_fp_detection_settings.vue';
import DuoFoundationalAgentsSettings from './duo_foundational_agents_settings.vue';

export default {
  name: 'AiCommonSettingsForm',
  components: {
    GlForm,
    GlAlert,
    GlButton,
    DuoAvailability,
    DuoExperimentBetaFeatures,
    DuoCoreFeaturesForm,
    DuoPromptCache,
    DuoFlowSettings,
    DuoSastFpDetectionSettings,
    DuoFoundationalAgentsSettings,
  },
  mixins: [glFeatureFlagMixin()],
  i18n: {
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    confirmButtonText: __('Save changes'),
  },
  inject: ['onGeneralSettingsPage', 'showFoundationalAgentsAvailability'],
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoFoundationalFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoSastFpDetectionAvailability: {
      type: Boolean,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
      default: true,
    },
    promptCacheEnabled: {
      type: Boolean,
      required: true,
    },
    foundationalAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      flowEnabled: this.duoRemoteFlowsAvailability,
      sastFpDetectionEnabled: this.duoSastFpDetectionAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
      foundationalFlowsEnabled: this.duoFoundationalFlowsAvailability,
      foundationalAgentsEnabledInput: this.foundationalAgentsEnabled,
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.duoAvailability;
    },
    hasExperimentCheckboxChanged() {
      return this.experimentsEnabled !== this.experimentFeaturesEnabled;
    },
    hasDuoCoreCheckboxChanged() {
      return this.duoCoreEnabled !== this.duoCoreFeaturesEnabled;
    },
    hasCacheCheckboxChanged() {
      return this.cacheEnabled !== this.promptCacheEnabled;
    },
    hasFlowFormChanged() {
      return this.flowEnabled !== this.duoRemoteFlowsAvailability;
    },
    hasFoundationalFlowsFormChanged() {
      return this.foundationalFlowsEnabled !== this.duoFoundationalFlowsAvailability;
    },
    hasSastFpDetectionFormChanged() {
      return (
        this.glFeatures.aiExperimentSastFpDetection &&
        this.sastFpDetectionEnabled !== this.duoSastFpDetectionAvailability
      );
    },
    hasFoundationalAgentsEnabledChanged() {
      return this.foundationalAgentsEnabled !== this.foundationalAgentsEnabledInput;
    },
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasDuoCoreCheckboxChanged ||
        this.hasCacheCheckboxChanged ||
        this.hasParentFormChanged ||
        this.hasFlowFormChanged ||
        this.hasFoundationalFlowsFormChanged ||
        this.hasSastFpDetectionFormChanged ||
        this.hasFoundationalAgentsEnabledChanged
      );
    },
    showWarning() {
      return this.hasAvailabilityChanged && this.warningAvailability;
    },
    warningAvailability() {
      return (
        this.availability === AVAILABILITY_OPTIONS.NEVER_ON ||
        this.availability === AVAILABILITY_OPTIONS.DEFAULT_OFF
      );
    },
    warningMessage() {
      const optsWithWarning = [AVAILABILITY_OPTIONS.DEFAULT_OFF, AVAILABILITY_OPTIONS.NEVER_ON];
      return optsWithWarning.includes(this.availability)
        ? this.$options.i18n.defaultOffWarning
        : '';
    },
    disableConfigCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit');
    },
    onRadioChanged(value) {
      this.availability = value;
      this.$emit('radio-changed', value);
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
      this.$emit('experiment-checkbox-changed', value);
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
      this.$emit('duo-core-checkbox-changed', value);
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
      this.$emit('cache-checkbox-changed', value);
    },
    onFlowCheckboxChanged(value) {
      this.flowEnabled = value;
      this.$emit('duo-flow-checkbox-changed', value);
    },
    onFoundationalFlowsCheckboxChanged(value) {
      this.foundationalFlowsEnabled = value;
      this.$emit('duo-foundational-flows-checkbox-changed', value);
    },
    onSastFpDetectionCheckboxChanged(value) {
      this.sastFpDetectionEnabled = value;
      this.$emit('duo-sast-fp-detection-changed', value);
    },
    onFoundationalAgentsEnabledChanged(value) {
      this.foundationalAgentsEnabledInput = value;
      this.$emit('duo-foundational-agents-changed', value);
    },
  },
};
</script>

<template>
  <gl-form @submit.prevent="submitForm">
    <slot name="ai-common-settings-top"></slot>
    <duo-availability :duo-availability="availability" @change="onRadioChanged" />

    <duo-core-features-form
      v-if="!onGeneralSettingsPage"
      :duo-core-features-enabled="duoCoreEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="duoCoreCheckboxChanged"
    />

    <duo-experiment-beta-features
      :experiment-features-enabled="experimentsEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="experimentCheckboxChanged"
    />

    <duo-flow-settings
      :duo-remote-flows-availability="duoRemoteFlowsAvailability"
      :duo-foundational-flows-availability="duoFoundationalFlowsAvailability"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="onFlowCheckboxChanged"
      @change-foundational-flows="onFoundationalFlowsCheckboxChanged"
    />

    <duo-sast-fp-detection-settings
      v-if="glFeatures.aiExperimentSastFpDetection"
      :duo-sast-fp-detection-availability="duoSastFpDetectionAvailability"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="onSastFpDetectionCheckboxChanged"
    />

    <duo-prompt-cache
      :prompt-cache-enabled="cacheEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="onCacheCheckboxChanged"
    />

    <duo-foundational-agents-settings
      v-if="showFoundationalAgentsAvailability"
      :enabled="foundationalAgentsEnabledInput"
      @change="onFoundationalAgentsEnabledChanged"
    />

    <slot name="ai-common-settings-bottom"></slot>
    <gl-alert
      v-if="showWarning"
      :dismissible="false"
      variant="warning"
      data-testid="duo-settings-show-warning-alert"
    >
      {{ warningMessage }}
    </gl-alert>
    <gl-button class="gl-mt-6" type="submit" variant="confirm" :disabled="!hasFormChanged">
      {{ $options.i18n.confirmButtonText }}
    </gl-button>
  </gl-form>
</template>
