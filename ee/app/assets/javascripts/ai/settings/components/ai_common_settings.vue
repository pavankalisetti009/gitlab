<script>
import { GlLink, GlSprintf, GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';

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
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    neverOnWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned for all groups, subgroups, and projects.',
    ),
  },
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    areDuoSettingsLocked: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
    };
  },
  computed: {
    hasFormChanged() {
      return this.availability !== this.duoAvailability;
    },
    showWarning() {
      return this.hasFormChanged && this.warningAvailability;
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
  },
  methods: {
    submitForm() {
      this.$emit('submit', {
        duoAvailability: this.availability,
      });
    },
    onRadioChanged(value) {
      this.availability = value;
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/ai_features'),
};
</script>
<template>
  <settings-block :title="s__('AiPowered|GitLab Duo features')">
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'AiPowered|Configure AI-powered GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template #default>
      <gl-form @submit.prevent="submitForm">
        <duo-availability
          :duo-availability="availability"
          :are-duo-settings-locked="areDuoSettingsLocked"
          @change="onRadioChanged"
        />
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
