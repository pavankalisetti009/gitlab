<script>
import { GlAlert, GlFormGroup, GlFormRadioGroup, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { ENFORCEMENT_OPTIONS } from '../lib';

export default {
  name: 'EnforcementType',
  WARN_MODE_HELP_PATH: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    {
      anchor: 'warn-mode',
    },
  ),
  components: {
    GlAlert,
    GlFormGroup,
    GlFormRadioGroup,
    GlLink,
    GlSprintf,
  },
  props: {
    enforcement: {
      type: String,
      required: true,
    },
    hasLegacyWarnAction: {
      type: Boolean,
      required: false,
      default: false,
    },
    isWarnMode: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['change'],
  computed: {
    alertText() {
      if (this.isWarnMode) {
        return s__(
          'SecurityOrchestration|In warn mode, project approval settings are not overridden by policy and violations are reported, but fixes for the violations are not mandatory. %{linkStart}Learn more%{linkEnd}',
        );
      }

      return s__(
        'SecurityOrchestration|This policy was previously in warn mode, which was an experimental feature. Due to changes in the feature, warn mode is now disabled. To enable the new warn mode setting, update this property.',
      );
    },
    showAlert() {
      return this.isWarnMode || this.hasLegacyWarnAction;
    },
  },
  methods: {
    handleEnforcementChange(value) {
      this.$emit('change', value);
    },
  },
  ENFORCEMENT_OPTIONS,
};
</script>

<template>
  <gl-form-group :label="s__('SecurityOrchestration|Policy enforcement')" class="gl-mt-5">
    <gl-form-radio-group
      class="gl-inline-block"
      :options="$options.ENFORCEMENT_OPTIONS"
      :checked="enforcement"
      @change="handleEnforcementChange"
    />
    <gl-alert v-if="showAlert" variant="info" class="gl-mt-3" :dismissible="false">
      <gl-sprintf :message="alertText">
        <template #link="{ content }">
          <gl-link :href="$options.WARN_MODE_HELP_PATH" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </gl-form-group>
</template>
