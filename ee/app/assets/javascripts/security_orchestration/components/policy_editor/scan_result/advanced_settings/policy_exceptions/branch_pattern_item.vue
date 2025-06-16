<script>
import { debounce } from 'lodash';
import { GlButton, GlFormInput } from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  NAME,
  PATTERN,
  SOURCE,
  TARGET,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export default {
  SOURCE,
  TARGET,
  name: 'BranchPatternItem',
  components: {
    GlButton,
    GlFormInput,
  },
  props: {
    branch: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    sourcePattern() {
      return this.branch?.source?.pattern ?? '';
    },
    targetName() {
      return this.branch?.target?.name ?? '';
    },
  },
  created() {
    this.debouncedSetBranch = debounce(this.setBranch, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSetBranch.cancel();
  },
  methods: {
    removeItem() {
      this.$emit('remove');
    },
    setBranch(value, type) {
      const subKey = type === SOURCE ? PATTERN : NAME;

      this.$emit('set-branch', {
        ...this.branch,
        [type]: {
          [subKey]: value,
        },
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-5 md:gl-flex-row md:gl-items-center">
    <div class="gl-flex gl-w-full gl-flex-col gl-items-center md:gl-flex-row">
      <gl-form-input
        :id="`source-${branch.id}`"
        data-testid="source-input"
        :placeholder="s__('ScanResultPolicy|input source branch')"
        :value="sourcePattern"
        @input="debouncedSetBranch($event, $options.SOURCE)"
      />
      <span class="gl-mx-3">{{ __('to') }}</span>
      <gl-form-input
        :id="`target-${branch.id}`"
        data-testid="target-input"
        :placeholder="s__('ScanResultPolicy|input target branch')"
        :value="targetName"
        @input="debouncedSetBranch($event, $options.TARGET)"
      />
    </div>

    <gl-button :aria-label="__('Remove')" icon="remove" @click="removeItem" />
  </div>
</template>
