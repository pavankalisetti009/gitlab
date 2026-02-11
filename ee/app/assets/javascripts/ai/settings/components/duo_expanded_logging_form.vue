<script>
import { GlFormCheckbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoExpandedLoggingForm',
  i18n: {
    sectionTitle: s__('AiPowered|Data collection'),
    checkboxLabel: s__('AiPowered|Collect usage data'),
    checkboxHelpText: s__(
      'AiPowered|Allow GitLab to collect prompts, AI responses, and metadata from user interactions with GitLab Duo. This data helps to improve service quality and is not used to train models.',
    ),
  },
  components: {
    GlFormCheckbox,
  },
  inject: ['enabledExpandedLogging'],
  data() {
    return {
      expandedLogging: this.enabledExpandedLogging,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.expandedLogging);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="expandedLogging"
      data-testid="ai-logging-checkbox"
      @change="checkboxChanged"
    >
      <span>{{ $options.i18n.checkboxLabel }}</span>
      <template #help>
        {{ $options.i18n.checkboxHelpText }}
      </template>
    </gl-form-checkbox>
  </div>
</template>
