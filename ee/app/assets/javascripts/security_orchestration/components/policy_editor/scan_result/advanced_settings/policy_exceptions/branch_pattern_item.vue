<script>
import { GlButton, GlFormInput } from '@gitlab/ui';

export default {
  name: 'BranchPatternItem',
  components: {
    GlButton,
    GlFormInput,
  },
  props: {
    pattern: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    sourcePattern() {
      return this.pattern?.source?.pattern ?? '';
    },
    targetName() {
      return this.pattern?.target?.name ?? '';
    },
  },
  methods: {
    removeItem() {
      this.$emit('remove');
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-5 md:gl-flex-row md:gl-items-center">
    <div class="gl-flex gl-w-full gl-flex-col gl-items-center md:gl-flex-row">
      <gl-form-input
        id="source"
        data-testid="source-input"
        :placeholder="s__('ScanResultPolicy|input source branch')"
        :value="sourcePattern"
      />
      <span class="gl-mx-3">{{ __('to') }}</span>
      <gl-form-input
        id="target"
        data-testid="target-input"
        :placeholder="s__('ScanResultPolicy|input target branch')"
        :value="targetName"
      />
    </div>

    <gl-button :aria-label="__('Remove')" icon="remove" @click="removeItem" />
  </div>
</template>
