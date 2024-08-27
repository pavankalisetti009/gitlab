<script>
import { GlLink, GlSprintf, GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    GlForm,
    GlAlert,
    GlButton,
    SettingsBlock,
    DuoAvailability,
    DuoExperimentBetaFeatures,
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    neverOnWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned for all groups, subgroups, and projects.',
    ),
    settingsBlockTitle: __('GitLab Duo features'),
    settingsBlockDescription: s__(
      'AiPowered|Configure AI-powered GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
    ),
  },
  inject: ['duoAvailability', 'experimentFeaturesEnabled'],
  props: {
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
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.duoAvailability;
    },
    hasExperimentCheckboxChanged() {
      return this.experimentsEnabled !== this.experimentFeaturesEnabled;
    },
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasParentFormChanged
      );
    },
    showWarning() {
      return this.hasAvailabilityChanged && this.warningAvailability;
    },
    warningAvailability() {
      switch (this.availability) {
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return true;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return true;
        default:
          return false;
      }
    },
    warningMessage() {
      switch (this.availability) {
        case AVAILABILITY_OPTIONS.DEFAULT_OFF:
          return this.$options.i18n.defaultOffWarning;
        case AVAILABILITY_OPTIONS.NEVER_ON:
          return this.$options.i18n.neverOnWarning;
        default:
          return null;
      }
    },
    disableExperimentCheckbox() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit', {
        duoAvailability: this.availability,
        experimentFeaturesEnabled: this.experimentsEnabled,
      });
    },
    onRadioChanged(value) {
      this.availability = value;
    },
    onCheckboxChanged(value) {
      this.experimentsEnabled = value;
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/ai_features'),
};
</script>
<template>
  <settings-block :title="$options.i18n.settingsBlockTitle">
    <template #description>
      <gl-sprintf :message="$options.i18n.settingsBlockDescription">
        <template #link="{ content }">
          <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #default>
      <gl-form @submit.prevent="submitForm">
        <slot name="ai-common-settings-top"></slot>
        <duo-availability :duo-availability="availability" @change="onRadioChanged" />
        <duo-experiment-beta-features
          :experiment-features-enabled="experimentsEnabled"
          :disabled-checkbox="disableExperimentCheckbox"
          @change="onCheckboxChanged"
        />
        <slot name="ai-common-settings-bottom"></slot>
        <gl-alert v-if="showWarning" :dismissible="false" variant="warning">{{
          warningMessage
        }}</gl-alert>
        <div class="gl-mt-6">
          <gl-button type="submit" variant="confirm" :disabled="!hasFormChanged">
            {{ $options.i18n.confirmButtonText }}
          </gl-button>
        </div>
      </gl-form>
    </template>
  </settings-block>
</template>
