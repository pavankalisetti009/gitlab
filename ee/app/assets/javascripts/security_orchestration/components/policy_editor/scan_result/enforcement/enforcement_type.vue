<script>
import { GlAlert, GlFormGroup, GlFormRadioGroup, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  ENFORCEMENT_OPTIONS: [
    { value: 'warn', text: s__('SecurityOrchestration|Warn mode') },
    { value: 'enforce', text: s__('SecurityOrchestration|Strictly enforced') },
  ],
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
  computed: {
    alertText() {
      if (this.isWarnMode) {
        return s__(
          'SecurityOrchestration|In warn mode, project settings are checked and violations are reported, but fixes for the violations are not mandatory. %{linkStart}Learn more%{linkEnd}',
        );
      }

      return s__(
        'SecurityOrchestration|This policy was previously in warn mode, which was an experimental feature. Due to changes in the feature, warn mode is now disabled. To enable the new warn mode setting, update this property.',
      );
    },
    showAlert() {
      return this.isWarnMode || this.hasLegacyWarnAction;
    },
    warnModeHelpPath() {
      return helpPagePath('user/application_security/policies/merge_request_approval_policies', {
        anchor: 'warn-mode',
      });
    },
  },
  methods: {
    handleEnforcementChange(value) {
      this.$emit('change', value);
    },
  },
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
          <gl-link :href="warnModeHelpPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </gl-form-group>
</template>
