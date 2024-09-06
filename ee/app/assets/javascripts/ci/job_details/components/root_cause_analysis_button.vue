<script>
import { GlButton } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sendDuoChatCommand } from 'ee/ai/utils';

export default {
  components: {
    GlButton,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin()],
  inject: ['jobGid'],
  props: {
    jobFailed: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    callDuo() {
      sendDuoChatCommand({
        question: '/troubleshoot',
        resourceId: this.jobGid,
      });
    },
  },
};
</script>
<template>
  <gl-button
    v-if="glAbilities.troubleshootJobWithAi && jobFailed"
    icon="duo-chat"
    class="gl-mr-3"
    variant="confirm"
    data-testid="rca-duo-button"
    @click="callDuo"
  >
    {{ s__('Jobs|Troubleshoot') }}
  </gl-button>
</template>
