<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { AgenticDuoChat } from '@gitlab/duo-ui';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { clearDuoChatCommands } from 'ee/ai/utils';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import { parseGid } from '~/graphql_shared/utils';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_CLIENT_VERSION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
} from 'ee/ai/constants';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import { WIDTH_OFFSET } from '../../tanuki_bot/constants';

export default {
  name: 'DuoAgenticChatApp',
  components: {
    AgenticDuoChat,
  },
  provide() {
    return {
      renderGFM,
    };
  },
  props: {
    projectId: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    contextPresets: {
      query: getAiChatContextPresets,
      skip() {
        return !this.duoChatGlobalState.isAgenticChatShown;
      },
      variables() {
        return {
          projectId: this.projectId,
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
          questionCount: 4,
        };
      },
      update(data) {
        return data?.aiChatContextPresets?.questions || [];
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  data() {
    return {
      duoChatGlobalState,
      width: 550,
      height: window.innerHeight,
      minWidth: 550,
      minHeight: 400,
      // Explicitly initializing the props as null to ensure Vue makes it reactive.
      left: null,
      top: null,
      maxHeight: null,
      maxWidth: null,
      contextPresets: [],
      socket: null,
      workflowId: null,
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
    dimensions() {
      return {
        width: this.width,
        height: this.height,
        top: this.top,
        maxHeight: this.maxHeight,
        maxWidth: this.maxWidth,
        minWidth: this.minWidth,
        minHeight: this.minHeight,
        left: this.left,
      };
    },
    predefinedPrompts() {
      return this.contextPresets;
    },
  },
  watch: {
    'duoChatGlobalState.isAgenticChatShown': {
      handler(newVal) {
        if (!newVal) {
          // we reset chat when it gets closed, to avoid flickering the previously opened thread
          // information when it's opened again
          this.onNewChat();
        }
      },
    },
  },
  mounted() {
    this.setDimensions();
    window.addEventListener('resize', this.onWindowResize);
  },
  beforeDestroy() {
    // Remove the event listener when the component is destroyed
    window.removeEventListener('resize', this.onWindowResize);
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),
    setDimensions() {
      this.updateDimensions();
    },
    updateDimensions(width, height) {
      this.maxWidth = window.innerWidth - WIDTH_OFFSET;
      this.maxHeight = window.innerHeight;

      this.width = Math.min(width || this.width, this.maxWidth);
      this.height = Math.min(height || this.height, this.maxHeight);
      this.top = window.innerHeight - this.height;
      this.left = window.innerWidth - this.width;
    },
    onChatResize(e) {
      this.updateDimensions(e.width, e.height);
    },
    onWindowResize() {
      this.updateDimensions();
    },
    shouldStartNewChat(question) {
      return [GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE, GENIE_CHAT_RESET_MESSAGE].includes(
        question,
      );
    },
    onNewChat() {
      clearDuoChatCommands();
      this.setMessages([]);
      this.setLoading(false);
      this.workflowId = null;
    },
    onChatCancel() {
      // pushing last requestId of messages to canceled Request Id's
      this.setLoading(false);
      this.socket?.close();
      this.workflowId = null;
    },
    startWorkflow(goal) {
      if (this.socket) {
        this.socket.close();
      }

      this.socket = new WebSocket(`/api/v4/ai/duo_workflows/ws`);
      this.socket.onopen = () => {
        const startRequest = {
          startRequest: {
            workflowID: this.workflowId,
            clientVersion: DUO_WORKFLOW_CLIENT_VERSION,
            workflowDefinition: DUO_WORKFLOW_CHAT_DEFINITION,
            goal,
          },
        };

        this.socket.send(JSON.stringify(startRequest));
      };

      this.socket.onclose = this.onSocketClose;
      this.socket.onerror = this.onError;
      this.socket.onmessage = this.onMessageReceived;
    },
    onSocketClose() {
      this.socket = null;
      this.setLoading(false);
    },
    onMessageReceived(event) {
      event.data
        .text()
        .then((data) => {
          const action = JSON.parse(data);

          if (action.newCheckpoint) {
            const messages = JSON.parse(
              action.newCheckpoint.checkpoint,
            ).channel_values.ui_chat_log.map((msg, i) => {
              const requestId = `${this.workflowId}-${i}`;

              return {
                content: msg.content,
                requestId,
                message_type: msg.message_type === 'agent' ? 'assistant' : msg.message_type,
                role: msg.message_type === 'agent' ? 'assistant' : msg.message_type,
                tool_info: msg.tool_info,
              };
            });

            this.setMessages(messages);

            this.socket.send(JSON.stringify({ actionResponse: { requestID: action.requestID } }));
          }
        })
        .catch((err) => {
          this.onError(err);
        });
    },
    async onSendChatPrompt(question) {
      if (this.shouldStartNewChat(question)) {
        this.onNewChat();
        return;
      }

      if (!this.loading) {
        this.setLoading(true);
      }

      if (!this.workflowId) {
        try {
          const { data: { aiDuoWorkflowCreate: { workflow = {} } = {} } = {} } =
            await this.$apollo.mutate({
              mutation: duoWorkflowMutation,
              variables: {
                projectId: this.projectId,
                goal: question,
                workflowDefinition: DUO_WORKFLOW_CHAT_DEFINITION,
                agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
                preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
              },
              context: {
                headers: {
                  'X-GitLab-Interface': 'duo_chat',
                  'X-GitLab-Client-Type': 'web_browser',
                },
              },
            });
          this.workflowId = parseGid(workflow.id).id;
        } catch (err) {
          this.onError(err);
        }
      }

      const requestId = `${this.workflowId}-${this.messages?.length || 0}`;
      const userMessage = { content: question, role: 'user', requestId };

      this.startWorkflow(question);

      this.addDuoChatMessage(userMessage);
    },
    onChatClose() {
      this.duoChatGlobalState.isAgenticChatShown = false;
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
  },
};
</script>

<template>
  <div>
    <div v-if="duoChatGlobalState.isAgenticChatShown">
      <agentic-duo-chat
        id="duo-chat"
        :title="s__('DuoAgenticChat|GitLab Duo Agentic Chat')"
        :messages="messages"
        :is-loading="loading"
        :predefined-prompts="predefinedPrompts"
        :enable-code-insertion="false"
        :should-render-resizable="true"
        :with-feedback="false"
        :show-header="true"
        :dimensions="dimensions"
        @new-chat="onNewChat"
        @send-chat-prompt="onSendChatPrompt"
        @chat-cancel="onChatCancel"
        @chat-hidden="onChatClose"
        @chat-resize="onChatResize"
      />
    </div>
  </div>
</template>
