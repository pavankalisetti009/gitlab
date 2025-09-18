<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { WARN_MODE, EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';

export default {
  SELECTOR_ITEMS: [
    {
      header: s__('SecurityOrchestration|Exception Bypass (pre-approved)'),
      description: s__(
        'SecurityOrchestration|You have been granted bypass permissions for these policies based on organizational role or custom role assignments.',
      ),
      key: EXCEPTION_MODE,
    },
    {
      header: s__('SecurityOrchestration|Warn mode (bypass eligible)'),
      description: s__(
        'SecurityOrchestration|These policies are configured in warn mode. This allows you to bypass violations with proper justification.',
      ),
      key: WARN_MODE,
    },
  ],
  name: 'SecurityPolicyViolationsSelector',
  components: {
    GlButton,
  },
  methods: {
    selectKey(key) {
      this.$emit('select', key);
    },
  },
};
</script>

<template>
  <div>
    <div v-for="item in $options.SELECTOR_ITEMS" :key="item.key" class="gl-mt-7">
      <h5 data-testid="header">{{ item.header }}</h5>
      <div class="gl-flex gl-items-start">
        <p data-testid="description" class="gl-m-0 gl-pr-12">{{ item.description }}</p>
        <div>
          <gl-button category="primary" variant="confirm" @click="selectKey(item.key)">{{
            __('Continue')
          }}</gl-button>
        </div>
      </div>
    </div>
  </div>
</template>
