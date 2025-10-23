<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { WebAgenticDuoChat } from '@gitlab/duo-ui';
import { GlToggle, GlTooltipDirective } from '@gitlab/ui';
import getUserWorkflows from 'ee/ai/graphql/get_user_workflow.query.graphql';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { getCookie } from '~/lib/utils/common_utils';
import { getStorageValue, saveStorageValue } from '~/lib/utils/local_storage';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { clearDuoChatCommands, setAgenticMode } from 'ee/ai/utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
  DUO_WORKFLOW_STATUS_RUNNING,
  DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  DUO_CURRENT_WORKFLOW_STORAGE_KEY,
  DUO_CHAT_VIEWS,
} from 'ee/ai/constants';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import getAiChatAvailableModels from 'ee/ai/graphql/get_ai_chat_available_models.query.graphql';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { createWebSocket, closeSocket } from '~/lib/utils/websocket_utils';
import { fetchPolicies } from '~/lib/graphql';
import { logError } from '~/lib/logger';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { s__ } from '~/locale';
import { DUO_AGENTIC_MODE_COOKIE } from '../../tanuki_bot/constants';
import { WorkflowUtils } from '../utils/workflow_utils';
import { ApolloUtils } from '../utils/apollo_utils';
import {
  getCurrentModel,
  getDefaultModel,
  getModel,
  saveModel,
  isModelSelectionDisabled as checkModelSelectionDisabled,
} from '../utils/model_selection_utils';
import {
  buildWebsocketUrl,
  buildStartRequest,
  processWorkflowMessage,
} from '../utils/workflow_socket_utils';
import { getInitialDimensions, calculateDimensions } from '../utils/resize_utils';
import { validateAgentExists as validateAgent, prepareAgentSelection } from '../utils/agent_utils';
import { parseThreadForSelection, resetThreadContent } from '../utils/thread_utils';

export default {
  name: 'DuoAgenticChatApp',
  components: {
    WebAgenticDuoChat,
    GlToggle,
    ModelSelectDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    chatConfiguration: {
      default: () => ({
        title: s__('DuoAgenticChat|GitLab Duo Agentic Chat'),
        isAgenticAvailable: false,
      }),
    },
  },
  provide() {
    return {
      renderGFM,
      avatarUrl: window.gon?.current_user_avatar_url,
    };
  },
  props: {
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    namespaceId: {
      type: String,
      required: false,
      default: null,
    },
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    metadata: {
      type: String,
      required: false,
      default: null,
    },
    userModelSelectionEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    mode: {
      type: String,
      required: false,
      default: 'active',
    },
  },
  apollo: {
    agenticWorkflows: {
      query: getUserWorkflows,
      variables() {
        return {
          type: 'chat',
          first: 99999,
        };
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((edge) => edge.node) || [];
      },
      error(err) {
        this.onError(err);
      },
    },
    contextPresets: {
      query: getAiChatContextPresets,
      variables() {
        return {
          resourceId: this.resourceId,
          projectId: this.projectId,
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
          questionCount: 4,
        };
      },
      update(data) {
        return data?.aiChatContextPresets || {};
      },
      error(err) {
        this.onError(err);
      },
    },
    availableModels: {
      query: getAiChatAvailableModels,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      skip() {
        if (!this.userModelSelectionEnabled) return true;
        return !this.rootNamespaceId;
      },
      variables() {
        return {
          rootNamespaceId: this.rootNamespaceId,
        };
      },
      update(data) {
        const { selectableModels = [], defaultModel, pinnedModel } = data.aiChatAvailableModels;

        const models = selectableModels.map(({ ref, name }) => ({
          text: name,
          value: ref === defaultModel?.ref ? GITLAB_DEFAULT_MODEL : ref,
        }));

        this.pinnedModel = pinnedModel?.ref
          ? {
              text: pinnedModel.name,
              value: pinnedModel.ref,
            }
          : null;

        return models;
      },
      error(err) {
        this.onError(err);
      },
    },
    catalogAgents: {
      query: getConfiguredAgents,
      variables() {
        return this.projectId ? { projectId: this.projectId } : { groupId: this.namespaceId };
      },
      update(data) {
        return (data?.aiCatalogConfiguredItems.nodes || []).map((agent) => agent.item);
      },
      error(err) {
        this.onError(err);
      },
    },
    foundationalAgents: {
      query: getFoundationalChatAgents,
      update(data) {
        return (
          data?.aiFoundationalChatAgents.nodes.map((agent) => ({
            ...agent,
            foundational: true,
          })) || []
        );
      },
      variables() {
        return {
          projectId: this.projectId,
          namespaceId: this.namespaceId,
        };
      },
      error(err) {
        this.onError(err);
      },
    },
    agentConfig: {
      query: getAgentFlowConfig,
      variables() {
        return { agentVersionId: this.aiCatalogItemVersionId };
      },
      skip() {
        return !this.aiCatalogItemVersionId;
      },
      update(data) {
        return data?.aiCatalogAgentFlowConfig;
      },
    },
  },
  data() {
    const currentWorkflowRecord = getStorageValue(DUO_CURRENT_WORKFLOW_STORAGE_KEY);
    const currentWorkflowDefaultRecord = { activeThread: undefined, workflowId: null };
    const { activeThread, workflowId } = currentWorkflowRecord.exists
      ? currentWorkflowRecord.value
      : currentWorkflowDefaultRecord;

    return {
      agentConfig: null,
      duoChatGlobalState,
      ...getInitialDimensions(),
      contextPresets: [],
      availableModels: [],
      pinnedModel: null,
      socketManager: null,
      workflowId,
      workflowStatus: null,
      isProcessingToolApproval: false,
      agenticWorkflows: [],
      activeThread,
      multithreadedView: DUO_CHAT_VIEWS.CHAT,
      chatMessageHistory: [],
      selectedModel: null,
      catalogAgents: [],
      aiCatalogItemVersionId: '',
      foundationalAgents: [],
      selectedFoundationalAgent: null,
      agentDeletedError: '',
      isChatAvailable: true,
      isEmbedded: this.chatConfiguration?.defaultProps?.isEmbedded ?? false,
      // this is required for classic/agentic toggle
      // eslint-disable-next-line vue/no-unused-properties
      isAgenticAvailable: this.chatConfiguration?.isAgenticAvailable ?? false,
      // eslint-disable-next-line vue/no-unused-properties
      userId: this.activeTabData?.props?.userId,
      // I believe this is a default chat agent name
      duoChatTitle: s__('DuoAgenticChat|Duo Agent'),
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
    dimensions() {
      if (!this.isEmbedded) {
        return {};
      }

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
    defaultModel() {
      return getDefaultModel(this.availableModels);
    },
    currentModel: {
      get() {
        return getCurrentModel({
          availableModels: this.availableModels,
          pinnedModel: this.pinnedModel,
          selectedModel: this.selectedModel,
          isLoading: this.$apollo.queries.availableModels?.loading,
        });
      },
      set(val) {
        this.selectedModel = val;
      },
    },
    isModelSelectionDisabled() {
      return checkModelSelectionDisabled(this.pinnedModel);
    },
    modelSelectionDisabledTooltipText() {
      return this.isModelSelectionDisabled
        ? s__('ModelSelection|Model has been pinned by an administrator.')
        : '';
    },
    predefinedPrompts() {
      return this.contextPresets.questions || [];
    },
    additionalContext() {
      if (!this.contextPresets.aiResourceData) {
        return null;
      }

      return [
        {
          content: this.contextPresets.aiResourceData,
          // This field depends on INCLUDE_{CATEGORY}_CONTEXT unit primitive:
          // https://gitlab.com/gitlab-org/cloud-connector/gitlab-cloud-connector/-/blob/main/src/python/gitlab_cloud_connector/data_model/gitlab_unit_primitives.py?ref_type=heads#L37-47
          // Since there is no unit primitives for all resource types and there is no a general one, let's use the one for repository
          category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
          metadata: JSON.stringify({}), // This field is expected to be non-null json object
        },
      ];
    },
    duoAgenticModePreference: {
      get() {
        return getCookie(DUO_AGENTIC_MODE_COOKIE) === 'true';
      },
      set(value) {
        setAgenticMode({ agenticMode: value, saveCookie: true, isEmbedded: this.isEmbedded });
      },
    },
    agents() {
      return [...this.foundationalAgents, ...this.catalogAgents].map((agent) => ({
        ...agent,
        text: agent.name,
      }));
    },
    websocketUrl() {
      return buildWebsocketUrl({
        rootNamespaceId: this.rootNamespaceId,
        namespaceId: this.namespaceId,
        projectId: this.projectId,
        userModelSelectionEnabled: this.userModelSelectionEnabled,
        currentModel: this.currentModel,
        defaultModel: this.defaultModel,
      });
    },
    dynamicTitle() {
      if (!this.aiCatalogItemVersionId && !this.selectedFoundationalAgent) {
        return this.duoChatTitle;
      }

      let activeAgent = null;

      if (this.aiCatalogItemVersionId) {
        activeAgent = this.catalogAgents.find((agent) =>
          agent.versions.nodes.some((version) => version.id === this.aiCatalogItemVersionId),
        );
      } else {
        activeAgent = this.foundationalAgents.find(
          (agent) => agent.id === this.selectedFoundationalAgent.id,
        );
      }

      return activeAgent ? activeAgent.name : this.duoChatTitle;
    },
    window() {
      return window;
    },
  },
  watch: {
    'duoChatGlobalState.isAgenticChatShown': {
      handler(newVal) {
        if (newVal) {
          this.hydrateActiveThread();
        }
      },
    },
    workflowStatus(newStatus, oldStatus) {
      if (
        oldStatus === DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED &&
        newStatus !== DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED
      ) {
        this.isProcessingToolApproval = false;
      }
    },
    workflowId(newWorkflowId, oldWorkflowId) {
      if (newWorkflowId !== oldWorkflowId) {
        saveStorageValue(DUO_CURRENT_WORKFLOW_STORAGE_KEY, {
          workflowId: newWorkflowId,
          activeThread: newWorkflowId
            ? convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, parseInt(newWorkflowId, 10))
            : '',
        });
      }
    },
    mode(newMode) {
      this.switchMode(newMode);
    },
  },
  mounted() {
    // Only manage dimensions and resize when not isEmbedded
    if (!this.isEmbedded) {
      this.setDimensions();
      window.addEventListener('resize', this.onWindowResize);
    }
    this.switchMode(this.mode);
    this.loadDuoNextIfNeeded();
  },
  beforeDestroy() {
    // Remove the event listener when the component is destroyed
    if (!this.isEmbedded) {
      window.removeEventListener('resize', this.onWindowResize);
    }
    this.cleanupSocket();
    // Clear messages when component is destroyed to prevent state leaking
    // between mode switches (classic <-> agentic)
    this.setMessages([]);
    this.setLoading(false);
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),
    async loadDuoNextIfNeeded() {
      if (this.glFeatures.duoUiNext) {
        try {
          await import('fe_islands/duo_next/dist/duo_next');
        } catch (err) {
          logError('Failed to load frontend islands duo_next module', err);
        }
      }
    },
    switchMode(mode) {
      if (mode === 'active') {
        this.hydrateActiveThread();
      }
      if (mode === 'new') {
        this.onNewChat();
        this.$emit('change-title', '');
      }
      if (mode === 'history') {
        this.onBackToList();
        this.$emit('change-title', '');
      }
    },

    cleanupSocket() {
      if (this.socketManager) {
        closeSocket(this.socketManager);
        this.socketManager = null;
      }
    },

    cleanupState(resetWorkflowId = true) {
      this.setLoading(false);
      this.cleanupSocket();
      if (resetWorkflowId) {
        this.workflowId = null;
      }
      this.workflowStatus = null;
    },

    setDimensions() {
      this.updateDimensions();
    },
    updateDimensions(width, height) {
      const newDimensions = calculateDimensions({
        width,
        height,
        currentWidth: this.width,
        currentHeight: this.height,
      });

      Object.assign(this, newDimensions);
    },
    onChatResize(e) {
      this.$emit('chat-resize');
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
    onChatCancel() {
      this.cleanupState(false);
    },
    startWorkflow(goal, approval = {}, additionalContext) {
      this.cleanupSocket();

      const startRequest = buildStartRequest({
        workflowId: this.workflowId,
        workflowDefinition: this.selectedFoundationalAgent?.referenceWithVersion,
        goal,
        approval,
        additionalContext,
        agentConfig: this.agentConfig,
        metadata: this.metadata,
      });

      this.socketManager = createWebSocket(this.websocketUrl, {
        onMessage: this.onMessageReceived,
        onError: () => {
          // eslint-disable-next-line @gitlab/require-i18n-strings
          this.onError(new Error('Unable to connect to workflow service. Please try again.'));
        },
        onClose: () => {
          // Only set loading to false if we're not waiting for tool approval
          // and we don't have a pending workflow that will create a new connection
          if (this.workflowStatus !== DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED) {
            this.isProcessingToolApproval = false;
            this.setLoading(false);
          }
        },
      });

      this.socketManager.connect(startRequest);
    },

    async onMessageReceived(event) {
      try {
        const workflowData = await processWorkflowMessage(event, this.workflowId);

        if (!workflowData) {
          return; // No checkpoint to process
        }

        this.setMessages(workflowData.messages);
        this.workflowStatus = workflowData.status;

        if (workflowData.goal && !this.activeThread) {
          this.activeThread = workflowData.goal;
        }

        if (this.workflowStatus === DUO_WORKFLOW_STATUS_INPUT_REQUIRED) {
          this.setLoading(false);
        }
      } catch (err) {
        this.onError(err);
      }
    },

    async onSendChatPrompt(question) {
      if (this.shouldStartNewChat(question)) {
        this.onNewChat(null, true);
        return;
      }

      if (!this.loading) {
        this.setLoading(true);
      }

      if (!this.workflowId) {
        try {
          const { workflowId, threadId } = await ApolloUtils.createWorkflow(this.$apollo, {
            projectId: this.projectId,
            namespaceId: this.namespaceId,
            goal: question,
            activeThread: this.activeThread,
            aiCatalogItemVersionId: this.aiCatalogItemVersionId,
          });

          this.workflowId = workflowId;
          if (threadId) {
            this.activeThread = threadId;
          }
        } catch (err) {
          this.onError(err);
          this.setLoading(false);
          return;
        }
      }

      const requestId = `${this.workflowId}-${this.chatMessageHistory.length + (this.messages?.length || 0)}`;
      const userMessage = { content: question, role: 'user', requestId };
      this.startWorkflow(question, {}, this.additionalContext);
      this.addDuoChatMessage(userMessage);
    },
    onChatClose() {
      // Only manage global state when not isEmbedded
      // When isEmbedded, the parent container (AI Panel) manages the visibility
      if (!this.isEmbedded) {
        this.duoChatGlobalState.isAgenticChatShown = false;
      }
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
    handleApproveToolCall() {
      this.isProcessingToolApproval = true;
      this.startWorkflow('', { approval: {} }, this.additionalContext);
    },
    handleDenyToolCall(event) {
      this.isProcessingToolApproval = true;
      const message = event?.message || event;
      this.startWorkflow(
        '',
        {
          approval: undefined,
          rejection: { message },
        },
        this.additionalContext,
      );
    },
    async onThreadSelected(thread) {
      const { activeThread, workflowId } = parseThreadForSelection(thread);

      this.activeThread = activeThread;
      this.workflowId = workflowId;
      this.multithreadedView = DUO_CHAT_VIEWS.CHAT;
      this.chatMessageHistory = [];
      this.setMessages([]);
      this.cleanupState(false);

      await this.hydrateActiveThread();

      // Check if the thread's agent still exists after hydration
      this.validateAgentExists();

      // Notify parent to switch to active chat tab when embedded
      if (this.isEmbedded) {
        this.$emit('switch-to-active-tab', DUO_CHAT_VIEWS.CHAT);
      }

      if (this.$route?.path !== '/chat') {
        this.$router.push(`/chat`);
      }
    },
    async hydrateActiveThread() {
      if (this.workflowId && this.activeThread && !this.messages?.length) {
        await this.loadActiveThread();

        // Check if the thread's agent still exists after loading (for page load scenarios)
        this.validateAgentExists();

        if (this.workflowStatus === DUO_WORKFLOW_STATUS_RUNNING) {
          this.startWorkflow('');
        }
      }
    },
    async loadActiveThread() {
      try {
        this.setLoading(true);
        const data = await ApolloUtils.fetchWorkflowEvents(this.$apollo, this.activeThread);

        const parsedWorkflowData = WorkflowUtils.parseWorkflowData(data);
        const uiChatLog = parsedWorkflowData?.checkpoint?.channel_values?.ui_chat_log || [];
        const messages = WorkflowUtils.transformChatMessages(uiChatLog, this.workflowId);
        const [workflow] = data.duoWorkflowWorkflows.nodes ?? [];

        this.workflowStatus = parsedWorkflowData?.workflowStatus;
        this.aiCatalogItemVersionId = workflow?.aiCatalogItemVersionId;
        this.chatMessageHistory = messages;
        this.$emit('change-title', parsedWorkflowData?.workflowGoal);
      } catch (err) {
        this.onError(err);
      } finally {
        this.setLoading(false);
      }
    },
    onBackToList() {
      this.multithreadedView = DUO_CHAT_VIEWS.LIST;
      this.activeThread = undefined;
      this.chatMessageHistory = [];
      try {
        if (this.$apollo?.queries?.agenticWorkflows) {
          this.$apollo.queries.agenticWorkflows.refetch();
        }
      } catch (err) {
        this.onError(err);
      }
    },
    async onDeleteThread(threadId) {
      try {
        const success = await ApolloUtils.deleteWorkflow(this.$apollo, threadId);
        if (success) {
          this.$apollo.queries.agenticWorkflows?.refetch();
        }
      } catch (err) {
        this.onError(err);
      }
    },
    async onNewChat(agent, reuseAgent) {
      clearDuoChatCommands();
      this.setMessages([]);

      const threadContent = resetThreadContent();
      Object.assign(this, threadContent);

      this.cleanupState();
      this.$emit('change-title');

      const agentState = prepareAgentSelection(agent, reuseAgent);
      if (agentState) {
        Object.assign(this, agentState);
      }
    },
    onModelSelect(selectedModelValue) {
      const model = getModel(this.availableModels, selectedModelValue);

      if (model) {
        this.currentModel = model;
        saveModel(model);
        this.onNewChat(null, true);
      }
    },
    validateAgentExists() {
      const { isAvailable, errorMessage } = validateAgent(
        this.aiCatalogItemVersionId,
        this.catalogAgents,
      );

      this.isChatAvailable = isAvailable;
      this.agentDeletedError = errorMessage;

      return isAvailable;
    },
  },
};
</script>

<template>
  <div>
    <div v-if="glFeatures.duoUiNext" class="gl-border-l gl-absolute gl-bg-white">
      <!--
        In order to correctly pass data down to the <next-chat> Custom Element, follow the following principle:
        - as an **attribute** for primitives (string/number)
        - as a **DOM property with a `.prop` modifier** for complex data structures like objects/arrays/functions/etc
      -->
      <fe-island-duo-next
        :avatar-url="window.gon ? window.gon.current_user_avatar_url : null"
        :user-name="window.gon ? window.gon.current_user_fullname : null"
        :models.prop="availableModels"
        @change-model="({ detail: models }) => window.alert(models[0])"
      />
    </div>
    <web-agentic-duo-chat
      v-else
      id="duo-chat"
      :title="dynamicTitle"
      :messages="messages.length > 0 ? messages : chatMessageHistory"
      :is-loading="loading"
      :predefined-prompts="predefinedPrompts"
      :thread-list="agenticWorkflows"
      :multi-threaded-view="multithreadedView"
      :active-thread-id="activeThread"
      :is-multithreaded="true"
      :enable-code-insertion="false"
      :should-render-resizable="!isEmbedded"
      :with-feedback="false"
      :show-header="true"
      :show-studio-header="isEmbedded"
      :is-embedded="isEmbedded"
      :session-id="workflowId"
      badge-type="beta"
      :dimensions="dimensions"
      :is-tool-approval-processing="isProcessingToolApproval"
      :agents="agents"
      :is-chat-available="isChatAvailable"
      :error="multithreadedView === 'chat' ? agentDeletedError : ''"
      class="gl-h-full gl-w-full"
      @new-chat="onNewChat"
      @send-chat-prompt="onSendChatPrompt"
      @chat-cancel="onChatCancel"
      @chat-hidden="onChatClose"
      @chat-resize="onChatResize"
      @approve-tool="handleApproveToolCall"
      @deny-tool="handleDenyToolCall"
      @thread-selected="onThreadSelected"
      @back-to-list="onBackToList"
      @delete-thread="onDeleteThread"
      ><template #footer-controls>
        <div :class="{ 'gl-flex gl-justify-between': userModelSelectionEnabled }">
          <div class="gl-flex gl-px-4 gl-pb-2 gl-pt-5">
            <gl-toggle
              v-model="duoAgenticModePreference"
              :label="s__('DuoChat|Agentic mode (Beta)')"
              label-position="left"
            />
          </div>
          <div
            v-if="userModelSelectionEnabled"
            v-gl-tooltip
            :title="modelSelectionDisabledTooltipText"
            class="gl-mb-2 gl-mt-5 gl-block gl-min-w-0"
            data-testid="model-dropdown-container"
          >
            <model-select-dropdown
              with-default-model-tooltip
              :disabled="isModelSelectionDisabled"
              :is-loading="$apollo.queries.availableModels.loading"
              :items="availableModels"
              :selected-option="currentModel"
              :placeholder-dropdown-text="s__('ModelSelection|Select a model')"
              @select="onModelSelect"
            />
          </div>
        </div>
      </template>
    </web-agentic-duo-chat>
  </div>
</template>
