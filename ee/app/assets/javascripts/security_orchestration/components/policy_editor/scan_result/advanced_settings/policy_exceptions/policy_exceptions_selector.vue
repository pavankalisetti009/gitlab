<script>
import { GlButton } from '@gitlab/ui';
import { EXCEPTION_FULL_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export default {
  EXCEPTION_FULL_OPTIONS,
  name: 'PolicyExceptionsSelector',
  components: {
    GlButton,
  },
  methods: {
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
          {{ __('Select') }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
