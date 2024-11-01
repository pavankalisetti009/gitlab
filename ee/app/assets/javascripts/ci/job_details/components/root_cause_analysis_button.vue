<script>
import { GlButton } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

export default {
  components: {
    GlButton,
  },
  props: {
    canTroubleshootJob: {
      type: Boolean,
      required: true,
    },
    jobStatusGroup: {
      type: String,
      required: true,
    },
    jobId: {
      type: Number,
      required: false,
      default: null,
    },
    jobGid: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    resourceId() {
      return this.jobGid || convertToGraphQLId(TYPENAME_CI_BUILD, this.jobId);
    },
    jobFailed() {
      const failedGroups = ['failed', 'failed-with-warnings'];

      return failedGroups.includes(this.jobStatusGroup);
    },
  },
  methods: {
    callDuo() {
      sendDuoChatCommand({
        question: '/troubleshoot',
        resourceId: this.resourceId,
      });
    },
  },
};
</script>
<template>
  <gl-button
    v-if="jobFailed && canTroubleshootJob"
    icon="duo-chat"
    variant="confirm"
    data-testid="rca-duo-button"
    @click="callDuo"
  >
    {{ s__('Jobs|Troubleshoot') }}
  </gl-button>
</template>
