<script>
import { GlLink, GlToggle } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getAdvancedEditorValue } from './utils';

export default {
  FEEDBACK_ISSUE_LINK: 'https://gitlab.com/gitlab-org/gitlab/-/issues/545147',
  i18n: {
    feedbackLabel: __('Give us feedback'),
    labelDisabled: s__('SecurityOrchestration|Try advanced editor'),
    labelEnabled: s__('SecurityOrchestration|Back to standard editor'),
  },
  name: 'AdvancedEditorToggle',
  components: {
    GlLink,
    GlToggle,
  },
  props: {
    advancedEditorEnabled: {
      type: Boolean,
      required: false,
      default: getAdvancedEditorValue(),
    },
  },
  computed: {
    label() {
      const { labelEnabled, labelDisabled } = this.$options.i18n;

      return this.advancedEditorEnabled ? labelEnabled : labelDisabled;
    },
  },
  methods: {
    enableAdvancedEditor(value) {
      this.$emit('enable-advanced-editor', value);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-2">
    <gl-toggle
      label-position="left"
      :label="label"
      :value="advancedEditorEnabled"
      @change="enableAdvancedEditor"
    />
    <gl-link
      v-if="advancedEditorEnabled"
      class="md:gl-ml-auto"
      :href="$options.FEEDBACK_ISSUE_LINK"
      target="_blank"
    >
      {{ $options.i18n.feedbackLabel }}
    </gl-link>
  </div>
</template>
