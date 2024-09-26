<script>
import { GlButton } from '@gitlab/ui';
import { ACTION_AND_LABEL } from '../../constants';
import { REQUIRE_APPROVAL_TYPE, DISABLED_BOT_MESSAGE_ACTION } from '../lib';
import ApproverAction from './approver_action.vue';
import BotMessageAction from './bot_message_action.vue';

export default {
  ACTION_AND_LABEL,
  DISABLED_BOT_MESSAGE_ACTION,
  name: 'ActionSection',
  components: {
    GlButton,
    ApproverAction,
    BotMessageAction,
  },
  props: {
    actionIndex: {
      type: Number,
      required: true,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    initAction: {
      type: Object,
      required: true,
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isApproverAction() {
      return this.initAction.type === REQUIRE_APPROVAL_TYPE;
    },
    isFirstAction() {
      return this.actionIndex === 0;
    },
  },
  methods: {
    remove() {
      if (this.isApproverAction) {
        this.$emit('remove');
      } else {
        this.$emit('changed', this.$options.DISABLED_BOT_MESSAGE_ACTION);
      }
    },
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-mb-4 gl-ml-5 gl-text-gray-500"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>

    <div class="gl-flex gl-w-full">
      <div class="gl-flex-1">
        <approver-action
          v-if="isApproverAction"
          :init-action="initAction"
          :errors="errors"
          :existing-approvers="existingApprovers"
          @error="$emit('error')"
          @updateApprovers="$emit('updateApprovers', $event)"
          @changed="$emit('changed', $event)"
        />
        <bot-message-action v-else :init-action="initAction" />
      </div>
      <div class="security-policies-bg-gray-10">
        <gl-button
          icon="remove"
          category="tertiary"
          :aria-label="__('Remove')"
          data-testid="remove-action"
          @click="remove"
        />
      </div>
    </div>
  </div>
</template>
