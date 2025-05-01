<script>
import { GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from './duo_core_features_form.vue';

export default {
  name: 'AiCommonSettingsForm',
  components: {
    GlForm,
    GlAlert,
    GlButton,
    DuoAvailability,
    DuoExperimentBetaFeatures,
    DuoCoreFeaturesForm,
  },
  i18n: {
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    neverOnWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned for all groups, subgroups, and projects.',
    ),
    confirmButtonText: __('Save changes'),
  },
  inject: ['isDuoBaseAccessAllowed'],
  props: {
    duoAvailability: {
      type: String,
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
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
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
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasDuoCoreCheckboxChanged ||
        this.hasParentFormChanged
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
      switch (this.availability) {
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return this.$options.i18n.defaultOffWarning;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return this.$options.i18n.neverOnWarning;
        default:
          return '';
      }
    },
    disableExperimentCheckbox() {
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
  },
};
</script>

<template>
  <gl-form @submit.prevent="submitForm">
    <slot name="ai-common-settings-top"></slot>
    <duo-availability :duo-availability="availability" @change="onRadioChanged" />

    <duo-core-features-form
      v-if="isDuoBaseAccessAllowed"
      :duo-core-features-enabled="duoCoreEnabled"
      @change="duoCoreCheckboxChanged"
    />

    <duo-experiment-beta-features
      :experiment-features-enabled="experimentsEnabled"
      :disabled-checkbox="disableExperimentCheckbox"
      @change="experimentCheckboxChanged"
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
