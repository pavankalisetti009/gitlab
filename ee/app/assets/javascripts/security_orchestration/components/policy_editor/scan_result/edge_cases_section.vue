<script>
import { GlIcon, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import { __, s__ } from '~/locale';

export default {
  i18n: {
    unblockRulesText: s__(
      'ScanResultPolicy|Make approval rules optional using scan execution policies',
    ),
    popoverTitle: __('Information'),
    popoverDesc: s__(
      'ScanResultPolicy|Automatically make approval rules optional when scan artifacts are missing from the target branch and a scan is required by a scan execution policy. This option only works with an existing scan execution policy that has matching scanners.',
    ),
  },
  components: {
    GlIcon,
    GlFormCheckbox,
    GlPopover,
  },
  props: {
    policyTuning: {
      type: Object,
      required: false,
      default: () => ({ unblock_rules_using_execution_policies: false }),
    },
  },
  methods: {
    updateSetting(key, value) {
      const updates = { [key]: value };
      this.updatePolicy(updates);
    },
    updatePolicy(updates = {}) {
      this.$emit('changed', 'policy_tuning', { ...this.policyTuning, ...updates });
    },
  },
  UNBLOCK_RULES_KEY: 'unblock_rules_using_execution_policies',
  POPOVER_TARGET_SELECTOR: 'comparison-tuning-popover',
};
</script>

<template>
  <div class="gl-mt-3">
    <gl-form-checkbox
      :id="$options.UNBLOCK_RULES_KEY"
      class="gl-inline-block"
      :checked="policyTuning[$options.UNBLOCK_RULES_KEY]"
      @change="updateSetting($options.UNBLOCK_RULES_KEY, $event)"
    >
      {{ $options.i18n.unblockRulesText }}
      <gl-icon :id="$options.POPOVER_TARGET_SELECTOR" name="information-o" />
    </gl-form-checkbox>

    <gl-popover :target="$options.POPOVER_TARGET_SELECTOR" :title="$options.i18n.popoverTitle">
      {{ $options.i18n.popoverDesc }}
    </gl-popover>
  </div>
</template>
