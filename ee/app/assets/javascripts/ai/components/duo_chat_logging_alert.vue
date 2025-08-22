<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { getCookie, setCookie } from '~/lib/utils/common_utils';
import { DUO_AGENTIC_CHAT_LOGGING_ALERT } from 'ee/ai/constants';

export default {
  name: 'DuoChatLoggingAlert',
  components: {
    GlAlert,
    GlSprintf,
  },
  props: {
    metadata: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isDismissed: true,
    };
  },
  computed: {
    hasAlert() {
      return this.metadata?.isTeamMember && this.metadata?.extendedLogging && !this.isDismissed;
    },
  },
  mounted() {
    this.getLoggingAlertDismissState();
  },
  methods: {
    onDismiss() {
      setCookie(DUO_AGENTIC_CHAT_LOGGING_ALERT, true);
      this.isDismissed = true;
    },
    getLoggingAlertDismissState() {
      this.isDismissed = getCookie(DUO_AGENTIC_CHAT_LOGGING_ALERT) === 'true';
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="hasAlert"
    :dismissible="true"
    variant="warning"
    class="gl-border-t"
    role="alert"
    data-testid="duo-alert-logging"
    :title="__('GitLab Team Member Notice: Chat Logging Active')"
    primary-button-link="https://internal.gitlab.com/handbook/product/ai-strategy/duo-logging/#logging-duo-chat-usage-by-gitlab-team-members-without-logging-their-names-or-user-id"
    :primary-button-text="__('Learn more')"
    @dismiss="onDismiss"
  >
    <ul class="gl-list-none gl-pl-0">
      <li class="gl-mt-3">
        <gl-sprintf
          :message="
            __(
              '%{bStart}What\'s logged:%{bEnd} Your questions, contexts (files, issues, MRs, etc.), and Duo\'s responses',
            )
          "
        >
          <template #b="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>

      <li class="gl-mt-3">
        <gl-sprintf
          :message="
            __(
              '%{bStart}Which interfaces are affected:%{bEnd} usage of Duo Chat in Web and IDEs as well as Duo Agentic Chat in Web and IDEs',
            )
          "
        >
          <template #b="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>

      <li class="gl-mt-3">
        <gl-sprintf
          :message="
            __(
              '%{bStart}Privacy safeguards:%{bEnd} Your name and user ID are not logged as structured fields',
            )
          "
        >
          <template #b="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>

      <li class="gl-mt-3">
        <gl-sprintf
          :message="
            __(
              '%{bStart}Purpose:%{bEnd} This data helps us improve Duo Chat and will never be used for performance evaluation. Note: The in-app feedback form states \'GitLab team members cannot see the AI content.\' This does not apply for team members\' interactions with the chat.',
            )
          "
        >
          <template #b="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>

      <li class="gl-mt-3">
        <gl-sprintf
          :message="
            __(
              '%{bStart}Customers are not affected:%{bEnd} we never log customer usage of Duo Chat (unless specifically requested by the customer)',
            )
          "
        >
          <template #b="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </li>
    </ul>
  </gl-alert>
</template>
