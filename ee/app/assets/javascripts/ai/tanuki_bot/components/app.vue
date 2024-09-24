<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlDuoChat } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import { __, s__ } from '~/locale';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { helpPagePath } from '~/helpers/help_page_helper';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { clearDuoChatCommands } from 'ee/ai/utils';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import Tracking from '~/tracking';
import {
  i18n,
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAN_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
} from 'ee/ai/constants';
import { TANUKI_BOT_TRACKING_EVENT_NAME, SLASH_COMMANDS, MESSAGE_TYPES } from '../constants';
import TanukiBotSubscriptions from './tanuki_bot_subscriptions.vue';

export default {
  name: 'TanukiBotChatApp',
  i18n: {
    gitlabChat: s__('DuoChat|GitLab Duo Chat'),
    giveFeedback: s__('DuoChat|Give feedback'),
    source: __('Source'),
    experiment: __('Experiment'),
    askAQuestion: s__('DuoChat|Ask a question about GitLab'),
    exampleQuestion: s__('DuoChat|For example, %{linkStart}what is a fork%{linkEnd}?'),
    whatIsAForkQuestion: s__('DuoChat|What is a fork?'),
    GENIE_CHAT_LEGAL_GENERATED_BY_AI: i18n.GENIE_CHAT_LEGAL_GENERATED_BY_AI,
    predefinedPrompts: [
      __('How do I change my password in GitLab?'),
      __('How do I fork a project?'),
      __('How do I clone a repository?'),
      __('How do I create a template?'),
    ],
  },
  SLASH_COMMANDS,
  helpPagePath: helpPagePath('policy/experiment-beta-support', { anchor: 'beta' }),
  components: {
    GlDuoChat,
    DuoChatCallout,
    TanukiBotSubscriptions,
  },
  mixins: [Tracking.mixin()],
  provide() {
    return {
      renderGFM,
    };
  },
  props: {
    userId: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    aiMessages: {
      query: getAiMessages,
      result({ data }) {
        if (data?.aiMessages?.nodes) {
          this.setMessages(data.aiMessages.nodes);
        }
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  data() {
    return {
      duoChatGlobalState,
      clientSubscriptionId: uuidv4(),
      toolName: i18n.GITLAB_DUO,
      error: '',
      isResponseTracked: false,
      cancelledRequestIds: [],
      completedRequestId: null,
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
    computedResourceId() {
      if (this.hasCommands) {
        return this.duoChatGlobalState.commands[0].resourceId;
      }

      return this.resourceId || this.userId;
    },
    hasCommands() {
      return this.duoChatGlobalState.commands.length > 0;
    },
  },
  watch: {
    'duoChatGlobalState.commands': {
      handler(commands) {
        if (commands?.length) {
          const { question, variables } = commands[0];
          this.onSendChatPrompt(question, variables);
        }
      },
    },
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),
    isClearOrResetMessage(question) {
      return [
        GENIE_CHAT_CLEAN_MESSAGE,
        GENIE_CHAT_CLEAR_MESSAGE,
        GENIE_CHAT_RESET_MESSAGE,
      ].includes(question);
    },
    onChatCancel() {
      // pushing last requestId of messages to canceled Request Id's
      this.cancelledRequestIds.push(this.messages[this.messages.length - 1].requestId);
      this.setLoading(false);
    },
    onMessageReceived(aiCompletionResponse) {
      this.addDuoChatMessage(aiCompletionResponse);
      if (aiCompletionResponse.role.toLowerCase() === MESSAGE_TYPES.TANUKI) {
        this.completedRequestId = aiCompletionResponse.requestId;
        clearDuoChatCommands();
      }
    },
    onMessageStreamReceived(aiCompletionResponse) {
      if (aiCompletionResponse.requestId !== this.completedRequestId) {
        this.addDuoChatMessage(aiCompletionResponse);
      }
    },
    onResponseReceived(requestId) {
      if (this.isResponseTracked) {
        return;
      }

      performance.mark('response-received');
      performance.measure('prompt-to-response', 'prompt-sent', 'response-received');
      const [{ duration }] = performance.getEntriesByName('prompt-to-response');

      this.track('ai_response_time', {
        property: requestId,
        value: duration,
      });

      performance.clearMarks();
      performance.clearMeasures();
      this.isResponseTracked = true;
    },
    onSendChatPrompt(question, variables = {}) {
      performance.mark('prompt-sent');
      this.completedRequestId = null;
      this.isResponseTracked = false;

      if (!this.isClearOrResetMessage(question)) {
        this.setLoading();
      }
      this.$apollo
        .mutate({
          mutation: chatMutation,
          variables: {
            question,
            resourceId: this.computedResourceId,
            clientSubscriptionId: this.clientSubscriptionId,
            ...variables,
          },
        })
        .then(({ data: { aiAction = {} } = {} }) => {
          if (!this.isClearOrResetMessage(question)) {
            this.track('submit_gitlab_duo_question', {
              property: aiAction.requestId,
            });
          }
          if ([GENIE_CHAT_CLEAN_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE].includes(question)) {
            this.$apollo.queries.aiMessages.refetch();
          } else {
            this.addDuoChatMessage({
              ...aiAction,
              content: question,
            });
          }
        })
        .catch((err) => {
          this.addDuoChatMessage({
            content: question,
          });
          this.onError(err);
          this.setLoading(false);
        });
    },
    onChatClose() {
      this.duoChatGlobalState.isShown = false;
    },
    onCalloutDismissed() {
      this.duoChatGlobalState.isShown = true;
    },
    onTrackFeedback({ feedbackChoices, didWhat, improveWhat, message } = {}) {
      if (message) {
        const { id, requestId, extras, role, content } = message;
        this.$apollo
          .mutate({
            mutation: duoUserFeedbackMutation,
            variables: {
              input: {
                aiMessageId: id,
                trackingEvent: {
                  category: TANUKI_BOT_TRACKING_EVENT_NAME,
                  action: 'click_button',
                  label: 'response_feedback',
                  property: feedbackChoices.join(','),
                  extra: {
                    improveWhat,
                    didWhat,
                    prompt_location: 'after_content',
                  },
                },
              },
            },
          })
          .catch(() => {
            // silent failure because of fire and forget
          });

        this.addDuoChatMessage({
          requestId,
          role,
          content,
          extras: { ...extras, hasFeedback: true },
        });
      }
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
  },
};
</script>

<template>
  <div>
    <div v-if="duoChatGlobalState.isShown">
      <!-- Renderless component for subscriptions -->
      <tanuki-bot-subscriptions
        :user-id="userId"
        :client-subscription-id="clientSubscriptionId"
        :cancelled-request-ids="cancelledRequestIds"
        @message="onMessageReceived"
        @message-stream="onMessageStreamReceived"
        @response-received="onResponseReceived"
        @error="onError"
      />

      <gl-duo-chat
        id="duo-chat"
        :slash-commands="$options.SLASH_COMMANDS"
        :title="$options.i18n.gitlabChat"
        :messages="messages"
        :error="error"
        :is-loading="loading"
        :predefined-prompts="$options.i18n.predefinedPrompts"
        :badge-type="null"
        :tool-name="toolName"
        :canceled-request-ids="cancelledRequestIds"
        class="duo-chat-container"
        @chat-cancel="onChatCancel"
        @send-chat-prompt="onSendChatPrompt"
        @chat-hidden="onChatClose"
        @track-feedback="onTrackFeedback"
      />
    </div>
    <duo-chat-callout @callout-dismissed="onCalloutDismissed" />
  </div>
</template>
