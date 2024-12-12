<script>
import { GlLink, GlSprintf, GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
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
    PageHeading,
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
    configurationPageTitle: s__('AiPowered|Configuration'),
    movedAlertTitle: s__('AiPowered|GitLab Duo settings have moved'),
    movedAlertDescriptionText: s__(
      'AiPowered|To make it easier to configure GitLab Duo, the settings have moved to a more visible location. To access them, go to ',
    ),
    movedAlertButton: s__('AiPowered|View GitLab Duo settings'),
  },
  inject: [
    'duoAvailability',
    'experimentFeaturesEnabled',
    'onGeneralSettingsPage',
    'configurationSettingsPath',
  ],
  props: {
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroup: {
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
    movedAlertDescription() {
      const path = this.isGroup ? 'Settings > GitLab Duo' : 'Admin Area > GitLab Duo';
      return `${this.$options.i18n.movedAlertDescriptionText}%{linkStart}${path}%{linkEnd}.`;
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
  <div>
    <template v-if="onGeneralSettingsPage">
      <settings-block class="gl-mb-5 !gl-pt-5" :title="$options.i18n.settingsBlockTitle">
        <template #default>
          <gl-alert
            variant="info"
            :title="$options.i18n.movedAlertTitle"
            :dismissible="false"
            class="gl-mb-5"
            data-testid="duo-moved-settings-alert"
          >
            <gl-sprintf :message="movedAlertDescription">
              <template #link="{ content }">
                <gl-link class="!gl-no-underline" :href="configurationSettingsPath">{{
                  content
                }}</gl-link>
              </template>
            </gl-sprintf>
          </gl-alert>
        </template>
      </settings-block>
    </template>
    <template v-else>
      <page-heading :heading="$options.i18n.configurationPageTitle">
        <template #description>
          <span data-testid="configuration-page-subtitle">
            <gl-sprintf :message="$options.i18n.settingsBlockDescription">
              <template #link="{ content }">
                <gl-link :href="$options.aiFeaturesHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>
      </page-heading>
      <gl-form @submit.prevent="submitForm">
        <slot name="ai-common-settings-top"></slot>
        <duo-availability :duo-availability="availability" @change="onRadioChanged" />
        <duo-experiment-beta-features
          :experiment-features-enabled="experimentsEnabled"
          :disabled-checkbox="disableExperimentCheckbox"
          @change="onCheckboxChanged"
        />
        <slot name="ai-common-settings-bottom"></slot>
        <gl-alert
          v-if="showWarning"
          :dismissible="false"
          variant="warning"
          data-testid="duo-settings-show-warning-alert"
          >{{ warningMessage }}</gl-alert
        >
        <div class="gl-mt-6">
          <gl-button type="submit" variant="confirm" :disabled="!hasFormChanged">
            {{ $options.i18n.confirmButtonText }}
          </gl-button>
        </div>
      </gl-form>
    </template>
  </div>
</template>
