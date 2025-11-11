<script>
import { GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'CheckboxCell',
  components: {
    GlFormCheckbox,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    isSelected: {
      type: Boolean,
      required: true,
    },
    isSelectedLimitReached: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    disabled() {
      return this.isSelectedLimitReached && !this.isSelected;
    },
  },
  methods: {
    handleChange(checked) {
      if (checked) {
        this.$emit('selectItem', this.item, true);
      } else {
        this.$emit('selectItem', this.item, false);
      }
    },
  },
};
</script>
<template>
  <gl-form-checkbox
    :checked="isSelected"
    :disabled="disabled"
    class="gl-inline"
    @change="handleChange"
  >
    <span class="gl-sr-only">{{ __('Select item') }}</span>
  </gl-form-checkbox>
</template>
