<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { EXCEPTION_FULL_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export default {
  EXCEPTION_FULL_OPTIONS,
  name: 'PolicyExceptionsSelector',
  components: {
    GlButton,
  },
  props: {
    selectedExceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  methods: {
    buttonText(key) {
      return this.exceptionSelected(key) ? __('Update') : __('Select');
    },
    exceptionSelected(key) {
      return key in (this.selectedExceptions || {});
    },
    selectItem(key) {
      this.$emit('select', key);
    },
  },
};
</script>

<template>
  <div>
    <div
      v-for="(option, index) in $options.EXCEPTION_FULL_OPTIONS"
      :key="option.key"
      :class="{ 'gl-border-none': index === 0 }"
      class="gl-border-t gl-flex"
      data-testid="exception-type"
    >
      <div>
        <h4>{{ option.header }}</h4>
        <p>{{ option.description }}</p>
        <p>
          <strong>{{ __('Example:') }}</strong>
          <span>{{ option.example }}</span>
        </p>
      </div>
      <div class="gl-pt-4">
        <gl-button category="primary" variant="confirm" @click="selectItem(option.key)">
          {{ buttonText(option.key) }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
