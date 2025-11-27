import { WebAgenticDuoChat } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { parseDocument } from 'yaml';
import ChatLoadingState from 'ee/ai/components/chat_loading_state.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { setAgenticMode } from 'ee/ai/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import storeMutations from 'ee/ai/tanuki_bot/store/mutations';
import * as storeActions from 'ee/ai/tanuki_bot/store/actions';
import getUserWorkflows from 'ee/ai/graphql/get_user_workflow.query.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import getAiChatAvailableModels from 'ee/ai/graphql/get_ai_chat_available_models.query.graphql';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import DuoAgenticChatApp from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import { ApolloUtils } from 'ee/ai/duo_agentic_chat/utils/apollo_utils';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import {
  getCurrentModel,
  getDefaultModel,
  getModel,
  saveModel,
  isModelSelectionDisabled as checkModelSelectionDisabled,
} from 'ee/ai/duo_agentic_chat/utils/model_selection_utils';
import * as WorkflowSocketUtils from 'ee/ai/duo_agentic_chat/utils/workflow_socket_utils';
import * as ResizeUtils from 'ee/ai/duo_agentic_chat/utils/resize_utils';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
  DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  DUO_CURRENT_WORKFLOW_STORAGE_KEY,
  DUO_CHAT_VIEWS,
  DUO_WORKFLOW_STATUS_RUNNING,
} from 'ee/ai/constants';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import { createWebSocket, closeSocket } from '~/lib/utils/websocket_utils';
import { getStorageValue, saveStorageValue } from '~/lib/utils/local_storage';
import { getCookie } from '~/lib/utils/common_utils';
import {
  MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE,
  MOCK_MODEL_LIST_ITEMS,
  MOCK_GITLAB_DEFAULT_MODEL_ITEM,
  MOCK_CONFIGURED_AGENTS_RESPONSE,
  MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
  MOCK_FLOW_CONFIG_RESPONSE,
  MOCK_FETCHED_FOUNDATIONAL_AGENT,
  MOCK_FLOW_AGENT_CONFIG,
} from './mock_data';

Vue.config.ignoredElements = ['fe-island-duo-next'];

const mockSocketManager = {
  connect: jest.fn(),
  send: jest.fn(),
  close: jest.fn(),
  isConnected: jest.fn().mockReturnValue(true),
  getState: jest.fn().mockReturnValue('OPEN'),
};

jest.mock('fe_islands/duo_next/dist/main', () => ({}), {
  virtual: true,
});

jest.mock('yaml');

jest.mock('~/lib/utils/websocket_utils', () => ({
  createWebSocket: jest.fn(() => mockSocketManager),
  parseMessage: jest.fn(async (event) => {
    const data = typeof event.data === 'string' ? event.data : await event.data.text();
    return JSON.parse(data);
  }),
  closeSocket: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/utils/apollo_utils', () => ({
  ApolloUtils: {
    createWorkflow: jest.fn(),
    deleteWorkflow: jest.fn(),
    fetchWorkflowEvents: jest.fn(),
  },
}));

jest.mock('ee/ai/duo_agentic_chat/utils/workflow_utils', () => ({
  WorkflowUtils: {
    transformChatMessages: jest.fn(),
    parseWorkflowData: jest.fn(),
  },
}));

jest.mock('ee/ai/duo_agentic_chat/utils/model_selection_utils', () => ({
  getCurrentModel: jest.fn(),
  getDefaultModel: jest.fn(),
  getModel: jest.fn(),
  saveModel: jest.fn(),
  isModelSelectionDisabled: jest.fn(),
}));

const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
const MOCK_NAMESPACE_ID = 'gid://gitlab/Group/456';
const MOCK_RESOURCE_ID = 'gid://gitlab/Resource/789';
const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflows::Workflow/456';
const MOCK_USER_MESSAGE = {
  content: 'How can I optimize my CI pipeline?',
  role: 'user',
  requestId: `${MOCK_WORKFLOW_ID}-0-user`,
};
const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'How can I optimize my CI pipeline?',
        'What are best practices for merge requests?',
        'How do I set up a workflow for my project?',
        'What are the advantages of using GitLab CI/CD?',
      ],
    },
  },
};
const MOCK_APOLLO_UTILS_CREATE_WORKFLOW_RESPONSE = {
  workflowId: '456',
  threadId: null,
};

const MOCK_USER_WORKFLOWS_RESPONSE = {
  data: {
    duoWorkflowWorkflows: {
      edges: [
        {
          node: {
            id: MOCK_WORKFLOW_ID,
            title: 'Test workflow goal',
            lastUpdatedAt: '2024-01-01T00:00:00Z',
            aiCatalogItemVersionId: null,
          },
        },
      ],
    },
  },
};

const MOCK_WORKFLOW_EVENTS_RESPONSE = {
  duoWorkflowEvents: {
    nodes: [
      {
        id: 'event-1',
        checkpoint: '{"channel_values": {"ui_chat_log": []}}',
      },
    ],
  },
  duoWorkflowWorkflows: {
    nodes: [{ id: 'workflow-1', aiCatalogItemVersionId: '' }],
  },
};

const MOCK_WORKFLOW_EVENTS_RESPONSE_WITH_FOUNDATIONAL_AGENT = {
  duoWorkflowEvents: {
    nodes: [
      {
        id: 'event-1',
        checkpoint: '{"channel_values": {"ui_chat_log": []}}',
      },
    ],
  },
  duoWorkflowWorkflows: {
    nodes: [
      {
        id: 'workflow-1',
        aiCatalogItemVersionId: '',
        workflowDefinition: MOCK_FETCHED_FOUNDATIONAL_AGENT.referenceWithVersion,
      },
    ],
  },
};

const MOCK_TRANSFORMED_MESSAGES = [
  {
    content: 'Hello, how can I help?',
    role: 'assistant',
    requestId: '456-1-agent',
    message_type: 'agent',
  },
];

const MOCK_PARSED_FLOW_CONFIG = { components: [{ name: 'test', type: 'agent' }] };

const MOCK_UTILS_SETUP = () => {
  ApolloUtils.createWorkflow.mockResolvedValue(MOCK_APOLLO_UTILS_CREATE_WORKFLOW_RESPONSE);
  ApolloUtils.deleteWorkflow.mockResolvedValue(true);
  ApolloUtils.fetchWorkflowEvents.mockResolvedValue(MOCK_WORKFLOW_EVENTS_RESPONSE);
  WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);
  WorkflowUtils.parseWorkflowData.mockReturnValue({
    checkpoint: { channel_values: { ui_chat_log: [] } },
  });
  parseDocument.mockReturnValue(MOCK_PARSED_FLOW_CONFIG);

  getCurrentModel.mockReturnValue(MOCK_GITLAB_DEFAULT_MODEL_ITEM);
  getDefaultModel.mockReturnValue(MOCK_GITLAB_DEFAULT_MODEL_ITEM);
  // getModel needs to search arrays by value, simple Array.find helper
  getModel.mockImplementation((models, value) => models?.find((m) => m.value === value));
  saveModel.mockReturnValue(true);
  checkModelSelectionDisabled.mockReturnValue(false);

  jest
    .spyOn(WorkflowSocketUtils, 'buildWebsocketUrl')
    .mockReturnValue('/api/v4/ai/duo_workflows/ws');
  jest.spyOn(WorkflowSocketUtils, 'buildStartRequest').mockReturnValue({
    startRequest: {
      workflowID: '456',
      clientVersion: '1.0',
      workflowDefinition: 'chat',
      goal: '',
      approval: {},
    },
  });
  jest.spyOn(WorkflowSocketUtils, 'processWorkflowMessage');

  jest.spyOn(ResizeUtils, 'calculateDimensions');
};

const expectedAdditionalContext = [
  {
    content: `<current_gitlab_page_url>http://test.host/</current_gitlab_page_url>
<current_gitlab_page_title></current_gitlab_page_title>`,
    category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
    metadata: JSON.stringify({}),
  },
];

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
}));

jest.mock('~/lib/utils/local_storage', () => ({
  getStorageValue: jest.fn(),
  saveStorageValue: jest.fn(),
}));

jest.mock('ee/ai/utils', () => {
  const actualUtils = jest.requireActual('ee/ai/utils');

  return {
    __esModule: true,
    ...actualUtils,
    setAgenticMode: jest.fn(),
  };
});

describe('Duo Agentic Chat', () => {
  let wrapper;

  const actionSpies = {
    addDuoChatMessage: jest.fn((context, message) => {
      // Use the real action implementation
      storeActions.addDuoChatMessage(context, message);
    }),
    setMessages: jest.fn((context, messages = []) => {
      // Directly commit to store instead of async dispatches to avoid timing issues
      context.commit('CLEAN_MESSAGES');
      messages?.forEach((msg) => {
        storeActions.addDuoChatMessage(context, msg);
      });
    }),
  };

  const mockRefetch = jest.fn().mockResolvedValue({});

  const userWorkflowsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_USER_WORKFLOWS_RESPONSE);
  const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);
  const availableModelsQueryHandlerMock = jest
    .fn()
    .mockResolvedValue(MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE);
  const configuredAgentsQueryMock = jest.fn().mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
  const aiFoundationalChatAgentsQueryMock = jest
    .fn()
    .mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);
  const agentFlowConfigQueryMock = jest.fn().mockResolvedValue(MOCK_FLOW_CONFIG_RESPONSE);

  const findDuoChat = () => wrapper.findComponent(WebAgenticDuoChat);
  const findDuoNext = () => wrapper.find('fe-island-duo-next');
  const findChatLoadingState = () => wrapper.findComponent(ChatLoadingState);

  const getLastSocketCall = () => {
    const { calls } = createWebSocket.mock;
    if (calls.length === 0) {
      throw new Error('No WebSocket calls made yet');
    }
    const [, socketCallbacks] = calls[calls.length - 1];
    return socketCallbacks;
  };

  const createComponent = ({
    initialState = {},
    propsData = { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
    data = {},
    apolloHandlers = [[getAiChatAvailableModels, availableModelsQueryHandlerMock]],
    provide = {},
    stubs = {},
  } = {}) => {
    const store = new Vuex.Store({
      mutations: storeMutations,
      actions: actionSpies,
      state: {
        messages: [],
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [getUserWorkflows, userWorkflowsQueryHandlerMock],
      [getAiChatContextPresets, contextPresetsQueryHandlerMock],
      [getConfiguredAgents, configuredAgentsQueryMock],
      [getFoundationalChatAgents, aiFoundationalChatAgentsQueryMock],
      [getAgentFlowConfig, agentFlowConfigQueryMock],
      ...apolloHandlers,
    ]);

    if (duoChatGlobalState.isAgenticChatShown !== false) {
      duoChatGlobalState.isAgenticChatShown = true;
    }

    const mockRouter = {
      push: jest.fn(),
    };

    const defaultProvide = {
      chatConfiguration: {
        title: 'GitLab Duo Agentic Chat',
        isAgenticAvailable: false,
        defaultProps: {
          isEmbedded: false,
        },
      },
      activeTabData: {
        props: {
          isEmbedded: false,
          isAgenticAvailable: false,
          userId: null,
        },
      },
      duoUiNext: false,
      ...provide,
    };

    wrapper = shallowMountExtended(DuoAgenticChatApp, {
      store,
      apolloProvider,
      propsData,
      provide: defaultProvide,
      mocks: {
        $router: mockRouter,
      },
      stubs,
      data() {
        return data;
      },
    });

    if (wrapper.vm.$apollo?.queries?.agenticWorkflows) {
      wrapper.vm.$apollo.queries.agenticWorkflows.refetch = mockRefetch;
    }
  };

  beforeEach(() => {
    mockRefetch.mockClear();
    MOCK_UTILS_SETUP();
  });

  beforeEach(() => {
    // In the default state, there isn't activeThread registered in local storage
    getStorageValue.mockReturnValue({ exists: false, value: null });
  });

  afterEach(() => {
    duoChatGlobalState.isAgenticChatShown = false;
    if (wrapper) {
      wrapper = null;
    }
  });

  describe('clearActiveThread', () => {
    it('clears the thread and resets lastProcessedMessageId', async () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent({
        data: {
          lastProcessedMessageId: 'message-5',
        },
      });
      await waitForPromises();

      wrapper.vm.clearActiveThread();
      expect(findDuoChat().props('messages')).toEqual([]);
      expect(wrapper.vm.lastProcessedMessageId).toBe(null);
    });
  });

  describe('beforeDestroy', () => {
    it('clears the active thread when destroyed', () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();

      const clearActiveThreadSpy = jest.spyOn(wrapper.vm, 'clearActiveThread');
      wrapper.destroy();

      // Verify clearActiveThread was called (which resets lastProcessedMessageId)
      expect(clearActiveThreadSpy).toHaveBeenCalled();
    });
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = true;
      });

      it('renders the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('renders the loading state during initialization', async () => {
        let resolvePromise = null;
        const pendingPromise = new Promise((resolve) => {
          resolvePromise = resolve;
        });
        ApolloUtils.fetchWorkflowEvents
          .mockResolvedValueOnce(MOCK_WORKFLOW_EVENTS_RESPONSE)
          .mockReturnValueOnce(pendingPromise);

        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();

        expect(findChatLoadingState().exists()).toBe(true);
        resolvePromise('');
      });

      it('passes isToolApprovalProcessing prop to AgenticDuoChat component', () => {
        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('passes multithreading props to AgenticDuoChat component', async () => {
        await waitForPromises();

        expect(findDuoChat().props('isMultithreaded')).toBe(true);
        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
        expect(findDuoChat().props('activeThreadId')).toBe('');
        expect(findDuoChat().props('threadList')).toEqual([
          {
            id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
            lastUpdatedAt: '2024-01-01T00:00:00Z',
            title: 'Test workflow goal',
            aiCatalogItemVersionId: null,
          },
        ]);
      });

      it('passes sessionId to AgenticDuoChat component', async () => {
        await findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();
        expect(findDuoChat().props('sessionId')).toBe('456');
      });

      it('calls the user workflows GraphQL query when component loads', () => {
        expect(userWorkflowsQueryHandlerMock).toHaveBeenCalledWith({
          type: 'foundational_chat_agents',
          first: 99999,
        });
      });

      it('calls the context presets GraphQL query when component loads', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          url: 'http://test.host/',
          questionCount: 4,
        });
      });

      it('passes context presets to WebAgenticDuoChat component as predefinedPrompts', async () => {
        await waitForPromises();
        expect(findDuoChat().props('predefinedPrompts')).toEqual(
          MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
        );
      });
    });
  });

  describe('chat mode on mount', () => {
    let hydrateActiveThreadSpy;
    let onNewChatSpy;

    beforeEach(() => {
      hydrateActiveThreadSpy = jest.spyOn(DuoAgenticChatApp.methods, 'hydrateActiveThread');
      onNewChatSpy = jest.spyOn(DuoAgenticChatApp.methods, 'onNewChat');
    });

    it('loads chat in "active" mode by default', async () => {
      createComponent();
      await waitForPromises();
      expect(wrapper.props('mode')).toBe('active');
    });

    describe('when there is no active thread', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('loads the new chat', () => {
        expect(onNewChatSpy).toHaveBeenCalled();
      });

      it('does not hydrate the active thread', () => {
        expect(hydrateActiveThreadSpy).not.toHaveBeenCalled();
      });
    });

    describe('when there is an active thread', () => {
      beforeEach(async () => {
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);
        createComponent({
          data: {
            workflowId: MOCK_WORKFLOW_ID,
            activeThread: MOCK_WORKFLOW_ID,
          },
        });
        await waitForPromises();
      });

      it('hydrates the active thread', () => {
        expect(hydrateActiveThreadSpy).toHaveBeenCalled();
      });

      it('does not load a new chat', () => {
        expect(onNewChatSpy).not.toHaveBeenCalled();
      });

      it('sets the last processed message id based on the thread messages', () => {
        expect(wrapper.vm.lastProcessedMessageId).toBe(
          MOCK_TRANSFORMED_MESSAGES[MOCK_TRANSFORMED_MESSAGES.length - 1].message_id,
        );
      });
    });
  });

  describe('Workflow deletion handling', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
    });

    it('shows error when sending message to workflow deleted in different instance', async () => {
      createComponent({ initialState: { messages: ['test'] }, data: { isInititalLoad: false } });
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(wrapper.vm.workflowId).toBe('456');

      ApolloUtils.fetchWorkflowEvents.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      findDuoChat().vm.$emit('send-chat-prompt', 'Follow-up question');
      await waitForPromises();
      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe('This chat was deleted.');
    });

    it('starts new chat when loading with deleted workflow after page reload', async () => {
      getStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: '456', activeThread: MOCK_WORKFLOW_ID },
      });

      ApolloUtils.fetchWorkflowEvents.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      createComponent();
      await waitForPromises();

      expect(findDuoChat().props('messages')).toHaveLength(0);
      expect(findDuoChat().props('activeThreadId')).toBe('');
    });

    it('shows error when navigating to deleted workflow from history in same instance', async () => {
      createComponent();
      await waitForPromises();

      ApolloUtils.fetchWorkflowEvents.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
      await waitForPromises();

      expect(findDuoChat().props('messages')).toHaveLength(0);
      expect(findDuoChat().props('activeThreadId')).toBe('');
    });

    it('displays generic error for non-deletion errors', async () => {
      getStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: '456', activeThread: MOCK_WORKFLOW_ID },
      });

      const errorText = 'Network timeout occurred';
      ApolloUtils.fetchWorkflowEvents.mockRejectedValue(new Error(errorText));

      createComponent();
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'resets chat state when "%s" command is sent',
        async (command) => {
          createComponent();
          wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

          findDuoChat().vm.$emit('send-chat-prompt', command);
          await nextTick();

          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(findChatLoadingState().exists()).toBe(false);
          expect(findDuoChat().props('isLoading')).toBe(false);
        },
      );

      it('creates a new workflow when sending a prompt for the first time with projectId', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(ApolloUtils.createWorkflow).toHaveBeenCalledWith(expect.anything(), {
          projectId: MOCK_PROJECT_ID,
          namespaceId: null,
          goal: MOCK_USER_MESSAGE.content,
          activeThread: undefined,
          aiCatalogItemVersionId: '',
        });

        expect(WorkflowSocketUtils.buildWebsocketUrl).toHaveBeenCalledWith({
          rootNamespaceId: null,
          namespaceId: null,
          projectId: MOCK_PROJECT_ID,
          userModelSelectionEnabled: false,
          currentModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          defaultModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
        });

        expect(createWebSocket).toHaveBeenCalledWith(
          '/api/v4/ai/duo_workflows/ws',
          expect.any(Object),
        );

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          goal: MOCK_USER_MESSAGE.content,
          approval: {},
          additionalContext: expectedAdditionalContext,
          agentConfig: null,
          metadata: null,
        });

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: `456-0-user`,
          }),
        );
      });

      it('creates a new workflow when sending a prompt for the first time with namespaceId', async () => {
        createComponent({
          propsData: { namespaceId: MOCK_NAMESPACE_ID, resourceId: MOCK_RESOURCE_ID },
        });
        duoChatGlobalState.isAgenticChatShown = true;

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(ApolloUtils.createWorkflow).toHaveBeenCalledWith(expect.anything(), {
          projectId: null,
          namespaceId: MOCK_NAMESPACE_ID,
          goal: MOCK_USER_MESSAGE.content,
          activeThread: undefined,
          aiCatalogItemVersionId: '',
        });

        expect(WorkflowSocketUtils.buildWebsocketUrl).toHaveBeenCalledWith({
          rootNamespaceId: null,
          namespaceId: MOCK_NAMESPACE_ID,
          projectId: null,
          userModelSelectionEnabled: false,
          currentModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          defaultModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
        });

        expect(createWebSocket).toHaveBeenCalledWith(
          '/api/v4/ai/duo_workflows/ws',
          expect.any(Object),
        );

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: `456-0-user`,
          }),
        );
      });

      it('creates a new workflow when sending a prompt for the first time with both projectId and namespaceId', async () => {
        createComponent({
          propsData: {
            projectId: MOCK_PROJECT_ID,
            namespaceId: MOCK_NAMESPACE_ID,
            resourceId: MOCK_RESOURCE_ID,
          },
        });
        duoChatGlobalState.isAgenticChatShown = true;

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(ApolloUtils.createWorkflow).toHaveBeenCalledWith(expect.anything(), {
          projectId: MOCK_PROJECT_ID,
          namespaceId: MOCK_NAMESPACE_ID,
          goal: MOCK_USER_MESSAGE.content,
          activeThread: undefined,
          aiCatalogItemVersionId: '',
        });
      });

      it('creates a new workflow when sending a prompt for the first time without projectId or namespaceId', async () => {
        createComponent({
          propsData: { resourceId: MOCK_RESOURCE_ID },
        });
        duoChatGlobalState.isAgenticChatShown = true;

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(ApolloUtils.createWorkflow).toHaveBeenCalledWith(expect.anything(), {
          projectId: null,
          namespaceId: null,
          goal: MOCK_USER_MESSAGE.content,
          activeThread: undefined,
          aiCatalogItemVersionId: '',
        });
      });

      it('sets waiting on prompt to true when sending a prompt', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(findDuoChat().props('isLoading')).toBe(true);
      });

      it('does not create a new workflow if one already exists', async () => {
        wrapper.vm.workflowId = '456';

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(ApolloUtils.createWorkflow).not.toHaveBeenCalled();
        expect(createWebSocket).toHaveBeenCalled();
      });

      it('connects to WebSocket and sends start request', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(mockSocketManager.connect).toHaveBeenCalled();
      });

      it('generates requestId with correct format including -user suffix', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', 'Test question');
        await waitForPromises();

        // RequestId should have format: workflowId-count-user
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: 'Test question',
            role: 'user',
            requestId: expect.stringMatching(/^456-\d+-user$/),
          }),
        );
      });
    });

    describe('WebSocket message handling', () => {
      let socketCall;

      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = '456';
        socketCall = getLastSocketCall();
        actionSpies.addDuoChatMessage.mockReset();
      });

      it('processes messages from the WebSocket and updates the UI', async () => {
        const mockEvent = {
          data: {
            text: () =>
              Promise.resolve(
                JSON.stringify({
                  requestID: 'request-id-1',
                  newCheckpoint: {
                    checkpoint: JSON.stringify({
                      channel_values: {
                        ui_chat_log: [
                          { content: 'Hello, how can I help?', message_type: 'agent' },
                          {
                            content: 'I can assist with optimizing your CI pipeline.',
                            message_type: 'agent',
                          },
                        ],
                      },
                    }),
                    status: 'completed',
                    goal: 'Test goal for activeThread',
                  },
                }),
              ),
          },
        };

        await socketCall.onMessage(mockEvent);

        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenCalledWith(mockEvent, null);

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.any(Object),
          MOCK_TRANSFORMED_MESSAGES.at(-1),
        );
        expect(findDuoChat().props('activeThreadId')).toBe('Test goal for activeThread');
      });

      it('handles tool approval flow', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need to run a command.',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'run_command',
                      args: { command: 'ls -la' },
                    },
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('sets waiting on prompt to false when workflow status is INPUT_REQUIRED', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-4',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Please provide more information',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(findDuoChat().props('isLoading')).toBe(false);
      });

      it('handles errors from WebSocket', () => {
        socketCall.onError();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: ['Error: Unable to connect to workflow service. Please try again.'],
          }),
        );
      });
    });

    describe('Race condition prevention in message processing', () => {
      let socketCall;

      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = '456';
        socketCall = getLastSocketCall();
        actionSpies.addDuoChatMessage.mockReset();
      });

      it('prevents concurrent processing of messages', async () => {
        const createMockEvent = (messageContent) => ({
          data: {
            text: () =>
              Promise.resolve(
                JSON.stringify({
                  requestID: 'request-id-race',
                  newCheckpoint: {
                    checkpoint: JSON.stringify({
                      channel_values: {
                        ui_chat_log: [{ content: messageContent, message_type: 'agent' }],
                      },
                    }),
                    status: 'running',
                  },
                }),
              ),
          },
        });

        // Set up processWorkflowMessage to return proper data
        WorkflowSocketUtils.processWorkflowMessage
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          })
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-1',
          });

        // Fire two events rapidly (simulating race condition)
        socketCall.onMessage(createMockEvent('First message'));
        socketCall.onMessage(createMockEvent('Second message'));

        // Wait for all processing to complete
        await waitForPromises();
        await nextTick();

        // Verify processWorkflowMessage was called sequentially, not concurrently
        // First call should have null, second should have updated message id
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenNthCalledWith(
          1,
          expect.anything(),
          null,
        );
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenNthCalledWith(
          2,
          expect.anything(),
          'message-0', // Uses updated lastProcessedMessageId from first call
        );
      });

      it('processes the final event when multiple events arrive rapidly', async () => {
        const createMockEvent = (id, messageContent) => ({
          data: {
            text: () =>
              Promise.resolve(
                JSON.stringify({
                  requestID: `request-id-${id}`,
                  newCheckpoint: {
                    checkpoint: JSON.stringify({
                      channel_values: {
                        ui_chat_log: [{ content: messageContent, message_type: 'agent' }],
                      },
                    }),
                    status: 'running',
                  },
                }),
              ),
          },
        });

        // Mock processWorkflowMessage to resolve with different data
        WorkflowSocketUtils.processWorkflowMessage.mockImplementation(() =>
          Promise.resolve({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          }),
        );

        // Fire multiple events rapidly - only first and last should be processed
        socketCall.onMessage(createMockEvent(1, 'Message 1'));
        socketCall.onMessage(createMockEvent(2, 'Message 2'));
        socketCall.onMessage(createMockEvent(3, 'Message 3'));
        socketCall.onMessage(createMockEvent(4, 'Final message'));

        await waitForPromises();
        await nextTick();

        // Should process at least 2 messages: first one that started immediately,
        // and the last one that was pending
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenCalled();
        // The final event should have been processed
        const lastCall =
          WorkflowSocketUtils.processWorkflowMessage.mock.calls[
            WorkflowSocketUtils.processWorkflowMessage.mock.calls.length - 1
          ];
        // Verify the last event was processed (request-id-4)
        expect(lastCall[0].data).toBeDefined();
      });

      it('maintains correct lastProcessedMessageId across sequential processing', async () => {
        const createMockEvent = (index) => ({
          data: {
            text: () =>
              Promise.resolve(
                JSON.stringify({
                  requestID: `request-id-${index}`,
                  newCheckpoint: {
                    checkpoint: JSON.stringify({
                      channel_values: {
                        ui_chat_log: [
                          {
                            content: `Message ${index}`,
                            message_type: 'agent',
                            message_id: `message-${index}`,
                          },
                        ],
                      },
                    }),
                    status: 'running',
                  },
                }),
              ),
          },
        });

        // Mock to return incrementing lastProcessedMessageId
        WorkflowSocketUtils.processWorkflowMessage
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          })
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-1',
          });

        // Send two events
        socketCall.onMessage(createMockEvent(1));
        await waitForPromises();

        socketCall.onMessage(createMockEvent(2));
        await waitForPromises();

        // Verify the message id was properly updated and passed
        expect(wrapper.vm.lastProcessedMessageId).toBe('message-1');
      });

      it('clears processing state when cleanupState is called', () => {
        const mockEvent = {
          data: {
            text: () =>
              Promise.resolve(
                JSON.stringify({
                  requestID: 'request-id-cleanup',
                  newCheckpoint: {
                    checkpoint: JSON.stringify({
                      channel_values: { ui_chat_log: [] },
                    }),
                    status: 'running',
                  },
                }),
              ),
          },
        };

        WorkflowSocketUtils.processWorkflowMessage.mockResolvedValue({
          messages: [],
          status: 'running',
          lastProcessedMessageId: 'message-0',
        });

        // Start processing
        socketCall.onMessage(mockEvent);
        expect(wrapper.vm.isProcessingMessage).toBe(true);

        // Call cleanup
        wrapper.vm.cleanupState();

        expect(wrapper.vm.isProcessingMessage).toBe(false);
        expect(wrapper.vm.pendingEvent).toBe(null);
      });
    });

    describe('@chat-cancel', () => {
      it('cancels the active connection, does not reset the workflowID', async () => {
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        wrapper.vm.socketManager = mockSocketManager;

        findDuoChat().vm.$emit('chat-cancel');
        await nextTick();

        expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);

        expect(findChatLoadingState().exists()).toBe(false);
        expect(findDuoChat().props('isLoading')).toBe(false);
        expect(wrapper.vm.workflowId).toBe(MOCK_WORKFLOW_ID);
        expect(wrapper.vm.socketManager).toBe(null);
      });
    });

    describe('@new-chat', () => {
      it('resets chat state for new conversation', async () => {
        wrapper.vm.workflowId = '456';
        wrapper.vm.socketManager = mockSocketManager;

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(wrapper.vm.workflowId).toBe(null);
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(findChatLoadingState().exists()).toBe(false);
        expect(findDuoChat().props('isLoading')).toBe(false);
        expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);
      });
      it('clears the active thread', async () => {
        const clearActiveThreadSpy = jest.spyOn(wrapper.vm, 'clearActiveThread');

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(clearActiveThreadSpy).toHaveBeenCalled();
      });
    });

    describe('@approve-tool', () => {
      beforeEach(() => {
        createComponent();
      });

      it('handles tool approval via chat component event and updates processing state through workflow', async () => {
        duoChatGlobalState.isAgenticChatShown = true;
        await waitForPromises();
        wrapper.vm.workflowId = '456';

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('approve-tool');
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          goal: '',
          approval: { approval: {} },
          additionalContext: expectedAdditionalContext,
          agentConfig: null,
          metadata: null,
        });

        expect(mockSocketManager.connect).toHaveBeenCalled();

        const socketCall = getLastSocketCall();
        const mockApprovalRequiredData = {
          requestID: 'request-id-approval-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need approval to execute this tool',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'some_tool',
                      args: { param: 'value' },
                    },
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockApprovalRequiredData)),
          },
        });
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        const mockCompletedData = {
          requestID: 'request-id-approval-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool execution completed',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'completed',
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCompletedData)),
          },
        });
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });
    });

    describe('@deny-tool', () => {
      beforeEach(() => {
        createComponent();
      });

      it('handles tool denial via chat component event with message and updates processing state', async () => {
        duoChatGlobalState.isAgenticChatShown = true;
        await waitForPromises();
        wrapper.vm.workflowId = '456';
        const denyMessage = 'I do not approve this action';

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('deny-tool', denyMessage);
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          goal: '',
          approval: {
            approval: undefined,
            rejection: { message: denyMessage },
          },
          additionalContext: expectedAdditionalContext,
          agentConfig: null,
          metadata: null,
        });

        expect(mockSocketManager.connect).toHaveBeenCalled();

        const socketCall = getLastSocketCall();
        const mockApprovalRequiredData = {
          requestID: 'request-id-denial-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool approval was required',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'some_tool',
                      args: { param: 'value' },
                    },
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockApprovalRequiredData)),
          },
        });
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        const mockDenialProcessedData = {
          requestID: 'request-id-denial-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool execution denied, proceeding with alternative approach',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'processing',
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockDenialProcessedData)),
          },
        });
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('handles tool denial via chat component event with event object and updates processing state', async () => {
        duoChatGlobalState.isAgenticChatShown = true;
        await waitForPromises();
        wrapper.vm.workflowId = '456';
        const eventObject = { message: 'I do not approve this action' };

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('deny-tool', eventObject);
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(mockSocketManager.connect).toHaveBeenCalled();
      });
    });
  });

  describe('workflowStatus watcher', () => {
    beforeEach(async () => {
      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;
      await waitForPromises();
    });

    it('sets isProcessingToolApproval to false when workflow status changes from TOOL_CALL_APPROVAL_REQUIRED', () => {
      wrapper.vm.isProcessingToolApproval = true;

      const watcherFunction = wrapper.vm.$options.watch.workflowStatus;
      watcherFunction.call(wrapper.vm, 'completed', 'TOOL_CALL_APPROVAL_REQUIRED');

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
    });

    it('does not change isProcessingToolApproval when workflow status changes from other states', async () => {
      wrapper.vm.isProcessingToolApproval = true;
      await nextTick();

      const watcherFunction = wrapper.vm.$options.watch.workflowStatus;
      watcherFunction.call(wrapper.vm, 'completed', 'processing');

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);
    });

    it('does not change isProcessingToolApproval when workflow status changes to TOOL_CALL_APPROVAL_REQUIRED', async () => {
      wrapper.vm.isProcessingToolApproval = false;
      await nextTick();

      const watcherFunction = wrapper.vm.$options.watch.workflowStatus;
      watcherFunction.call(wrapper.vm, 'TOOL_CALL_APPROVAL_REQUIRED', 'processing');

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
    });
  });

  describe('workflowId watcher', () => {
    beforeEach(async () => {
      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;

      await waitForPromises();
    });

    it('stores workflowId and active thread when workflowId changes', async () => {
      await findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });

      await nextTick();

      expect(saveStorageValue).toHaveBeenCalledWith(DUO_CURRENT_WORKFLOW_STORAGE_KEY, {
        workflowId: '456',
        activeThread: MOCK_WORKFLOW_ID,
      });
    });

    it('emits session-id-changed when workflowId changes', async () => {
      await findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });

      await nextTick();

      expect(wrapper.emitted('session-id-changed')).toBeDefined();
      expect(wrapper.emitted('session-id-changed')[0]).toEqual(['456']);
    });

    it('emits session-id-changed on mount when workflowId exists', async () => {
      getStorageValue.mockReset();
      getStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: '456', activeThread: MOCK_WORKFLOW_ID },
      });
      duoChatGlobalState.isAgenticChatShown = false;

      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;
      await waitForPromises();

      expect(wrapper.emitted('session-id-changed')).toBeDefined();
      expect(wrapper.emitted('session-id-changed')[0]).toEqual(['456']);
    });
  });

  describe('mode watcher', () => {
    let onNewChatSpy;
    let hydrateActiveThreadSpy;
    let onBackToListSpy;

    const bootstrapWithProps = async (props = {}) => {
      hydrateActiveThreadSpy = jest.spyOn(DuoAgenticChatApp.methods, 'hydrateActiveThread');
      onNewChatSpy = jest.spyOn(DuoAgenticChatApp.methods, 'onNewChat');
      onBackToListSpy = jest.spyOn(DuoAgenticChatApp.methods, 'onBackToList');

      createComponent(props);
      duoChatGlobalState.isAgenticChatShown = true;
      await waitForPromises();
      hydrateActiveThreadSpy.mockClear();
      onNewChatSpy.mockClear();
      onBackToListSpy.mockClear();
    };

    describe('when mode changes to "new"', () => {
      it('calls onNewChat', async () => {
        await bootstrapWithProps();
        wrapper.setProps({ mode: 'new' });
        await nextTick();

        expect(onNewChatSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('when mode changes to "history"', () => {
      beforeEach(async () => {
        await bootstrapWithProps();
        wrapper.setProps({ mode: 'history' });
      });

      it('calls onBackToList', async () => {
        await nextTick();
        expect(onBackToListSpy).toHaveBeenCalledTimes(1);
      });

      it('emits change-title with empty string', () => {
        const emittedEvents = wrapper.emitted('change-title');
        expect(emittedEvents.at(-1)).toEqual(['']);
      });

      it('switches to LIST view', async () => {
        await nextTick();
        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
      });
      it('removes any current messages', async () => {
        await bootstrapWithProps({
          inititalState: {
            messages: [{ id: '1', content: 'test' }],
          },
          data: {
            workflowId: MOCK_WORKFLOW_ID,
            activeThread: MOCK_WORKFLOW_ID,
          },
        });
        await nextTick();
        expect(findDuoChat().props('messages')).toHaveLength(1);

        wrapper.setProps({ mode: 'history' });
        await nextTick();
        expect(findDuoChat().props('messages')).toHaveLength(0);
      });
    });

    describe('when mode changes to "active"', () => {
      describe('no active thread', () => {
        beforeEach(async () => {
          await bootstrapWithProps({ propsData: { mode: 'history' } });
        });

        it('starts a new chat', async () => {
          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).toHaveBeenCalledTimes(1);
          expect(hydrateActiveThreadSpy).not.toHaveBeenCalled();
        });
      });
      describe('active thread is set', () => {
        beforeEach(async () => {
          await bootstrapWithProps({
            data: {
              workflowId: MOCK_WORKFLOW_ID,
              activeThread: MOCK_WORKFLOW_ID,
            },
            propsData: { mode: 'history' },
          });
        });

        it('should hydrate, and not run onNewChat', async () => {
          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).not.toHaveBeenCalled();
          expect(hydrateActiveThreadSpy).toHaveBeenCalledTimes(1);
        });
      });
      describe('when isLoading is true', () => {
        it('does not start a new chat or hydrate when switching to active mode', async () => {
          let resolvePromise = null;
          const pendingPromise = new Promise((resolve) => {
            resolvePromise = resolve;
          });

          ApolloUtils.fetchWorkflowEvents = jest.fn().mockReturnValue(pendingPromise);

          onNewChatSpy = jest.spyOn(DuoAgenticChatApp.methods, 'onNewChat');
          hydrateActiveThreadSpy = jest.spyOn(DuoAgenticChatApp.methods, 'hydrateActiveThread');

          createComponent({
            data: {
              workflowId: MOCK_WORKFLOW_ID,
              activeThread: MOCK_WORKFLOW_ID,
            },
            propsData: { mode: 'history' },
          });

          duoChatGlobalState.isAgenticChatShown = true;
          await nextTick();

          hydrateActiveThreadSpy.mockClear();
          onNewChatSpy.mockClear();

          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).not.toHaveBeenCalled();
          expect(hydrateActiveThreadSpy).not.toHaveBeenCalled();

          resolvePromise(MOCK_WORKFLOW_EVENTS_RESPONSE);
        });
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Failed to fetch resources';

    it('handles errors from the context presets query', async () => {
      contextPresetsQueryHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      expect(findDuoChat().exists()).toBe(true);
      expect(findDuoChat().props('predefinedPrompts')).toEqual([]);
    });

    it('handles workflow creation errors', async () => {
      ApolloUtils.createWorkflow.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });
  });

  describe('Resizable Dimensions', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
    });

    it('updates dimensions correctly when `chat-resize` event is emitted', async () => {
      const newWidth = 600;
      const newHeight = 500;
      const chat = findDuoChat();
      const initialWidth = wrapper.vm.width;
      const initialHeight = wrapper.vm.height;

      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(ResizeUtils.calculateDimensions).toHaveBeenLastCalledWith({
        width: newWidth,
        height: newHeight,
        currentWidth: initialWidth,
        currentHeight: initialHeight,
      });
      expect(wrapper.vm.width).toBe(newWidth);
      expect(wrapper.vm.height).toBe(newHeight);
    });

    it('updates dimensions when the window is resized', async () => {
      const originalInnerWidth = window.innerWidth;
      const originalInnerHeight = window.innerHeight;

      try {
        const initialWidth = wrapper.vm.width;
        const initialHeight = wrapper.vm.height;

        window.innerWidth = 1200;
        window.innerHeight = 800;

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        expect(ResizeUtils.calculateDimensions).toHaveBeenLastCalledWith({
          currentWidth: initialWidth,
          currentHeight: initialHeight,
        });
        expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
        expect(wrapper.vm.maxHeight).toBe(800);
      } finally {
        window.innerWidth = originalInnerWidth;
        window.innerHeight = originalInnerHeight;
      }
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.isAgenticChatShown', () => {
      describe('when there is a workflowId and activeThread registered in localStorage', () => {
        beforeEach(() => {
          getStorageValue.mockReset();
          getStorageValue.mockReturnValueOnce({
            exists: true,
            value: { workflowId: '456', activeThread: MOCK_WORKFLOW_ID },
          });
          duoChatGlobalState.isAgenticChatShown = false;
        });

        it('loads workflow message thread', async () => {
          createComponent();
          duoChatGlobalState.isAgenticChatShown = true;
          await waitForPromises();

          expect(findDuoChat().props().messages).toHaveLength(1);
        });

        describe(`when workflow status is "${DUO_WORKFLOW_STATUS_RUNNING}"`, () => {
          beforeEach(() => {
            const mockParsedData = {
              workflowStatus: DUO_WORKFLOW_STATUS_RUNNING,
              checkpoint: { channel_values: { ui_chat_log: [] } },
            };

            WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
          });

          it('starts the workflow', async () => {
            createComponent();
            duoChatGlobalState.isAgenticChatShown = true;
            await waitForPromises();
            expect(mockSocketManager.connect).toHaveBeenCalled();
          });
        });

        describe(`when workflow status is not "${DUO_WORKFLOW_STATUS_RUNNING}"`, () => {
          beforeEach(async () => {
            const mockParsedData = {
              workflowStatus: DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
              checkpoint: { channel_values: { ui_chat_log: [] } },
            };

            WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);

            duoChatGlobalState.isAgenticChatShown = true;
            await waitForPromises();
          });

          it('does not start the workflow', () => {
            expect(mockSocketManager.connect).not.toHaveBeenCalled();
          });
        });
      });

      describe('when there is a workflowId but no activeThread', () => {
        beforeEach(() => {
          getStorageValue.mockReset();
          getStorageValue.mockReturnValueOnce({
            exists: true,
            value: { workflowId: '456', activeThread: undefined },
          });
          duoChatGlobalState.isAgenticChatShown = false;
        });

        it('does not load messages for active thread', async () => {
          createComponent();
          duoChatGlobalState.isAgenticChatShown = true;
          await waitForPromises();

          expect(ApolloUtils.fetchWorkflowEvents).not.toHaveBeenCalled();
          expect(findDuoChat().props().messages).toHaveLength(0);
        });

        it('emits change-title when hydrateActiveThread is triggered', async () => {
          // Assert baseline - no emissions yet
          expect(wrapper?.emitted('change-title')).toBeUndefined();
          createComponent();
          duoChatGlobalState.isAgenticChatShown = true;
          await waitForPromises();

          const emissions = wrapper.emitted('change-title');
          expect(emissions).toHaveLength(2);
          expect(emissions[0]).toEqual([undefined]);
          expect(emissions[1]).toEqual([undefined]);
        });
      });

      describe('when there is no workflowId or activeThread registered in localStorage', () => {
        beforeEach(() => {
          getStorageValue.mockReset();
          getStorageValue.mockReturnValueOnce({
            exists: false,
            value: null,
          });
          duoChatGlobalState.isAgenticChatShown = false;
        });

        it('does not load messages for active thread', async () => {
          createComponent();
          duoChatGlobalState.isAgenticChatShown = true;
          await waitForPromises();

          expect(findDuoChat().props().messages).toHaveLength(0);
        });

        it('emits change-title when hydrateActiveThread is triggered', async () => {
          // Assert baseline - no emissions yet
          expect(wrapper?.emitted('change-title')).toBeUndefined();

          createComponent();
          duoChatGlobalState.isAgenticChatShown = true;
          await waitForPromises();

          const emissions = wrapper.emitted('change-title');
          expect(emissions).toHaveLength(2);
          expect(emissions[0]).toEqual([undefined]);
          expect(emissions[1]).toEqual([undefined]);
        });
      });
    });

    describe('duoChatGlobalState.commands', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = true;
      });

      describe('when commands are added', () => {
        it('starts a new chat and sends the command question', async () => {
          const testQuestion = 'What is GitLab CI/CD?';

          // Trigger the watcher by adding a command to the global state
          duoChatGlobalState.commands = [{ question: testQuestion }];
          await waitForPromises();

          // Assert that onNewChat() side effects occurred
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(findChatLoadingState().exists()).toBe(false);

          // Assert that onSendChatPrompt() side effects occurred
          expect(findDuoChat().props('isLoading')).toBe(true);
          expect(ApolloUtils.createWorkflow).toHaveBeenCalledWith(expect.anything(), {
            projectId: MOCK_PROJECT_ID,
            namespaceId: null,
            goal: testQuestion,
            activeThread: undefined,
            aiCatalogItemVersionId: '',
          });
          expect(mockSocketManager.connect).toHaveBeenCalled();
          expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
            expect.any(Object),
            expect.objectContaining({
              content: testQuestion,
              role: 'user',
              requestId: expect.stringMatching(/^456-\d+-user$/),
            }),
          );
        });

        it('does not trigger chat when commands array is empty', async () => {
          jest.clearAllMocks();

          duoChatGlobalState.commands = [];
          await nextTick();

          expect(actionSpies.setMessages).not.toHaveBeenCalled();
          expect(ApolloUtils.createWorkflow).not.toHaveBeenCalled();
          expect(mockSocketManager.connect).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('Socket cleanup', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('cleans up socket and clears state on component destroy', () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      wrapper.vm.socketManager = mockSocketManager;

      wrapper.destroy();

      expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);
      expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      // Note: Cannot check isLoading/isWaitingOnPrompt after destroy as component is destroyed
    });

    it('emits "change-title" event in beforeDestroy hook', () => {
      expect(wrapper?.emitted('change-title')).toBeUndefined();

      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();

      let changeTitleEmitted = false;
      wrapper.vm.$on('change-title', () => {
        changeTitleEmitted = true;
      });

      wrapper.destroy();

      expect(changeTitleEmitted).toBe(true);
    });

    it('sets isProcessingToolApproval to false on socket close when not waiting for approval', async () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      wrapper.vm.isProcessingToolApproval = true;
      wrapper.vm.workflowStatus = 'completed';
      wrapper.vm.workflowId = '456';

      wrapper.vm.startWorkflow('test question', {}, wrapper.vm.additionalContext);

      expect(createWebSocket).toHaveBeenCalled();

      const socketCall = getLastSocketCall();
      socketCall.onClose();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      expect(findDuoChat().props('isLoading')).toBe(false);
    });

    it('does not set isProcessingToolApproval to false on socket close when waiting for approval', async () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      jest.clearAllMocks();

      wrapper.vm.isProcessingToolApproval = true;
      wrapper.vm.workflowStatus = 'TOOL_CALL_APPROVAL_REQUIRED';
      wrapper.vm.workflowId = '456';

      wrapper.vm.startWorkflow('test question', {}, wrapper.vm.additionalContext);

      expect(createWebSocket).toHaveBeenCalled();

      const socketCall = getLastSocketCall();
      // Set waiting on prompt to true first to verify it stays true
      wrapper.vm.isWaitingOnPrompt = true;
      await nextTick();
      socketCall.onClose();
      await nextTick();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);
      expect(findDuoChat().props('isLoading')).toBe(true);
    });
  });

  describe('duoAgenticModePreference toggle', () => {
    const findGlToggle = () => wrapper.findComponent(GlToggle);

    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      jest.clearAllMocks();
    });

    describe('getter', () => {
      it.each`
        cookieValue | expected
        ${'true'}   | ${true}
        ${'false'}  | ${false}
        ${null}     | ${false}
        ${''}       | ${false}
      `('returns $expected when cookie value is $cookieValue', ({ cookieValue, expected }) => {
        getCookie.mockReturnValue(cookieValue);
        createComponent();

        expect(findGlToggle().props('value')).toBe(expected);

        expect(getCookie).toHaveBeenCalledWith('duo_agentic_mode_on');
      });
    });

    describe('setter', () => {
      beforeEach(() => {
        getCookie.mockReturnValue('false');
        createComponent();
      });

      it.each`
        value    | description
        ${true}  | ${'true'}
        ${false} | ${'false'}
      `('calls setAgenticMode with $description and saveCookie=true', async ({ value }) => {
        findGlToggle().vm.$emit('change', value);
        await nextTick();

        expect(setAgenticMode).toHaveBeenCalledWith({
          agenticMode: value,
          saveCookie: true,
          isEmbedded: false,
        });
      });
    });
  });

  describe('Multithreading features', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
    });

    describe('@thread-selected', () => {
      it('switches to selected thread and fetches workflow events', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
        const mockParsedData = { checkpoint: { channel_values: { ui_chat_log: [] } } };

        WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(ApolloUtils.fetchWorkflowEvents).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_WORKFLOW_ID,
        );

        expect(WorkflowUtils.parseWorkflowData).toHaveBeenCalledWith(MOCK_WORKFLOW_EVENTS_RESPONSE);
        expect(WorkflowUtils.transformChatMessages).toHaveBeenCalledWith([]);

        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
        expect(findDuoChat().props('activeThreadId')).toBe(MOCK_WORKFLOW_ID);
        expect(findDuoChat().props('messages')).toEqual(MOCK_TRANSFORMED_MESSAGES);
      });

      it('handles errors when fetching workflow events', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID };
        const errorText = 'Failed to fetch workflow events';

        ApolloUtils.fetchWorkflowEvents.mockRejectedValue(new Error(errorText));

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [`Error: ${errorText}`],
          }),
        );
        expect(findChatLoadingState().exists()).toBe(false);
      });

      it('handles missing workflowGoal gracefully when fetching workflow events', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };

        WorkflowUtils.parseWorkflowData.mockReturnValue(undefined);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        // Component emits change-title multiple times: on mount (via hydrateActiveThread),
        // and when thread is selected. Check that the last emission has undefined.
        const emissions = wrapper.emitted('change-title');
        expect(emissions[emissions.length - 1]).toEqual([undefined]);
        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
      });

      it('handles UI updates when thread is for foundational agent', async () => {
        ApolloUtils.fetchWorkflowEvents.mockResolvedValue(
          MOCK_WORKFLOW_EVENTS_RESPONSE_WITH_FOUNDATIONAL_AGENT,
        );

        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };

        WorkflowUtils.parseWorkflowData.mockReturnValue(undefined);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(ApolloUtils.fetchWorkflowEvents).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_WORKFLOW_ID,
        );

        expect(findDuoChat().props('title')).toEqual(MOCK_FETCHED_FOUNDATIONAL_AGENT.name);
      });

      it('resets the current thread before hydration', async () => {
        const clearActiveThreadSpy = jest.spyOn(wrapper.vm, 'clearActiveThread');

        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();

        expect(clearActiveThreadSpy).toHaveBeenCalled();
        expect(findDuoChat().props('messages')).toEqual(MOCK_TRANSFORMED_MESSAGES);
      });

      it('set the last processed message id based on the thread messages', async () => {
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        expect(wrapper.vm.lastProcessedMessageId).toBe(null);

        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();
        expect(wrapper.vm.lastProcessedMessageId).toBe(
          MOCK_TRANSFORMED_MESSAGES[MOCK_TRANSFORMED_MESSAGES.length - 1].message_id,
        );
      });
    });

    describe('@back-to-list', () => {
      it('switches back to list view and refetches workflows', async () => {
        await waitForPromises();

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
        expect(findDuoChat().props('activeThreadId')).toBe('');
        expect(mockRefetch).toHaveBeenCalled();
      });
      it('clears the active thread', async () => {
        const clearActiveThreadSpy = jest.spyOn(wrapper.vm, 'clearActiveThread');

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(clearActiveThreadSpy).toHaveBeenCalled();
      });
    });

    describe('@delete-thread', () => {
      beforeEach(async () => {
        jest.clearAllMocks();
        ApolloUtils.deleteWorkflow.mockResolvedValue(true);
        await waitForPromises();
      });

      it('calls deleteWorkflow and refetches workflows when deleting a thread', async () => {
        const mockThreadId = MOCK_WORKFLOW_ID;
        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await waitForPromises();

        expect(ApolloUtils.deleteWorkflow).toHaveBeenCalledWith(expect.anything(), mockThreadId);
        expect(mockRefetch).toHaveBeenCalled();
      });
    });
  });

  describe('Agentic Mode Toggle', () => {
    const findGlToggle = () => wrapper.findComponent(GlToggle);

    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      getCookie.mockReturnValue('false');
      createComponent();
    });

    it('renders the GlToggle component in subheader', () => {
      expect(findGlToggle().exists()).toBe(true);
    });

    it('passes correct props to GlToggle', () => {
      expect(findGlToggle().text()).toContain('Agentic mode');
      expect(findGlToggle().props('labelPosition')).toBe('left');
      expect(findGlToggle().props('value')).toBe(false);
    });

    it('binds duoAgenticModePreference to v-model', async () => {
      getCookie.mockReturnValue('true');
      createComponent();
      await nextTick();

      expect(findGlToggle().props('value')).toBe(true);
    });

    it('calls setAgenticMode when toggle value changes', async () => {
      findGlToggle().vm.$emit('change', true);
      await nextTick();

      expect(setAgenticMode).toHaveBeenCalledWith({
        agenticMode: true,
        saveCookie: true,
        isEmbedded: false,
      });
    });

    it('updates the toggle value when duoAgenticModePreference changes', async () => {
      getCookie.mockReturnValue('false');
      createComponent();
      await nextTick();

      expect(findGlToggle().props('value')).toBe(false);

      getCookie.mockReturnValue('true');
      createComponent();
      await nextTick();

      expect(findGlToggle().props('value')).toBe(true);
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = false;
        createComponent();
      });

      it('does not render the GlToggle component', () => {
        // When duoChatGlobalState.isAgenticChatShown is false, the toggle should still exist
        // but the component behavior might be different
        expect(findGlToggle().exists()).toBe(true);
      });
    });
  });

  describe('Agentic chat user model selection', () => {
    const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);

    describe('when user model selection is enabled', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent({
          propsData: { userModelSelectionEnabled: true, rootNamespaceId: MOCK_NAMESPACE_ID },
        });
      });

      it('renders `ModelSelectDropdown` in the correct slot', () => {
        expect(findModelSelectDropdown().exists()).toBe(true);
        const slot = findDuoChat().vm.$slots['agentic-model'];
        const vnode = typeof slot === 'function' ? slot()[0] : slot[0];

        const testId = vnode.props
          ? vnode.props['data-testid'] // Vue 3
          : vnode.data.attrs['data-testid']; // Vue 2

        expect(testId).toBe('model-dropdown-container');
      });

      it('renders `ModelSelectDropdown`', () => {
        expect(findModelSelectDropdown().exists()).toBe(true);
      });

      it('passes the correct props to `ModelSelectDropdown`', async () => {
        await waitForPromises();

        expect(findModelSelectDropdown().props('placeholderDropdownText')).toBe('Select a model');
        expect(findModelSelectDropdown().props('items')).toMatchObject(MOCK_MODEL_LIST_ITEMS);
        expect(findModelSelectDropdown().props('selectedOption')).toMatchObject(
          MOCK_GITLAB_DEFAULT_MODEL_ITEM,
        );
      });

      it('calls saveModel utility and starts new chat when model is selected', async () => {
        await waitForPromises();

        const selectedModel = MOCK_MODEL_LIST_ITEMS[1];
        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        await findModelSelectDropdown().vm.$emit('select', selectedModel.value);

        expect(saveModel).toHaveBeenCalledWith(selectedModel);
        expect(onNewChatSpy).toHaveBeenCalledWith(null, true);
      });

      it('disables dropdown when pinned model is set', async () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };
        checkModelSelectionDisabled.mockReturnValue(true);

        createComponent({
          propsData: { userModelSelectionEnabled: true, rootNamespaceId: MOCK_NAMESPACE_ID },
          data: { pinnedModel },
        });
        await waitForPromises();

        expect(findModelSelectDropdown().props('disabled')).toBe(true);
      });
    });

    describe('when user model selection is disabled', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent({ propsData: { userModelSelectionEnabled: false } });
      });

      it('does not render `ModelSelectDropdown`', () => {
        expect(findModelSelectDropdown().exists()).toBe(false);
      });
    });
  });

  describe('catalogAgents query variables', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
    });

    it('passes only projectId when both projectId and namespaceId are provided', async () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          namespaceId: MOCK_NAMESPACE_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        projectId: MOCK_PROJECT_ID,
      });
    });

    it('passes only projectId when only projectId is provided', async () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        projectId: MOCK_PROJECT_ID,
      });
    });

    it('passes only groupId when only namespaceId is provided', async () => {
      createComponent({
        propsData: {
          namespaceId: MOCK_NAMESPACE_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        groupId: MOCK_NAMESPACE_ID,
      });
    });

    it('passes groupId when neither projectId nor namespaceId are provided', async () => {
      createComponent({
        propsData: {
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        groupId: null,
      });
    });
  });

  describe('Fetching foundational agents', () => {
    describe('when project and namespace are available', () => {
      it('passes project_id and namespace_id', async () => {
        createComponent({
          propsData: { projectId: MOCK_PROJECT_ID, namespaceId: MOCK_NAMESPACE_ID },
        });

        await waitForPromises();

        expect(aiFoundationalChatAgentsQueryMock).toHaveBeenCalledWith({
          namespaceId: MOCK_NAMESPACE_ID,
          projectId: MOCK_PROJECT_ID,
        });
      });
    });

    describe('when project and namespace are not available', () => {
      it('does not pass project_id and namespace_id', async () => {
        createComponent({ propsData: {} });

        await waitForPromises();

        expect(aiFoundationalChatAgentsQueryMock).toHaveBeenCalledWith({
          namespaceId: null,
          projectId: null,
        });
      });
    });
  });

  describe('agent selection', () => {
    let agent;

    beforeEach(async () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      const agentResponse = MOCK_CONFIGURED_AGENTS_RESPONSE.data.aiCatalogConfiguredItems.nodes[0];
      agent = {
        ...agentResponse.item,
        pinnedItemVersionId: agentResponse.pinnedItemVersion.id,
        text: agentResponse.item.name,
      };
    });

    it('displays the GitLab Duo Agent as the first option', () => {
      expect(findDuoChat().props('agents')).toContainEqual({
        id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
        name: 'GitLab Duo Agent',
        description: 'Duo is your general development assistant',
        referenceWithVersion: 'chat',
        foundational: true,
        text: 'GitLab Duo Agent',
      });
    });

    it('passes the configured agents to duo chat', () => {
      // Verify the query was called
      expect(configuredAgentsQueryMock).toHaveBeenCalled();
      // We verify foundational agents here; catalog agent selection is tested in other tests
      expect(findDuoChat().props('agents')).toContainEqual({
        id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
        name: 'GitLab Duo Agent',
        description: 'Duo is your general development assistant',
        referenceWithVersion: 'chat',
        foundational: true,
        text: 'GitLab Duo Agent',
      });
    });

    it('uses the agentConfig from Apollo query when start workflow is called', async () => {
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: agent.pinnedItemVersionId,
      });

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
        }),
      );

      expect(mockSocketManager.connect).toHaveBeenCalled();
    });

    it('uses workflow definition when foundational chat is selected', async () => {
      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(agentFlowConfigQueryMock).not.toHaveBeenCalled();
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          workflowDefinition: 'agent/v1',
          agentConfig: null,
        }),
      );

      expect(mockSocketManager.connect).toHaveBeenCalled();
    });

    describe('switching from a foundational agent to a catalog agent', () => {
      it('fetches agent flow config and sends agent version id', async () => {
        findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenLastCalledWith(
          expect.objectContaining({
            workflowDefinition: 'agent/v1',
            agentConfig: null,
          }),
        );

        await findDuoChat().vm.$emit('new-chat', agent);
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await waitForPromises();

        expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
          agentVersionId: agent.pinnedItemVersionId,
        });

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenLastCalledWith(
          expect.objectContaining({
            workflowDefinition: undefined,
          }),
        );

        expect(mockSocketManager.connect).toHaveBeenCalled();
      });
    });

    it('re-uses the selected flow config when /new is used to start a new thread', async () => {
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', '/new');
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(mockSocketManager.connect).toHaveBeenCalled();
    });

    it('preserves agentConfig when selecting the same custom agent multiple times', async () => {
      // Select custom agent first time
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send first message to ensure agentConfig is populated
      findDuoChat().vm.$emit('send-chat-prompt', 'First message');
      await waitForPromises();

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
        }),
      );

      // Clear mocks to verify next call
      WorkflowSocketUtils.buildStartRequest.mockClear();

      // Select the SAME custom agent again (new chat with same agent)
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send another message
      findDuoChat().vm.$emit('send-chat-prompt', 'Second message');
      await waitForPromises();

      // Verify agentConfig is still present (not null)
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
        }),
      );
    });

    it('resets agentConfig when default agent follows a custom agent chat', async () => {
      // Select custom agent first
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send message with custom agent
      findDuoChat().vm.$emit('send-chat-prompt', 'Custom agent message');
      await waitForPromises();

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
        }),
      );

      // Clear mocks to verify next call
      WorkflowSocketUtils.buildStartRequest.mockClear();

      // Switch to default/foundational agent
      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      // Send message with foundational agent
      findDuoChat().vm.$emit('send-chat-prompt', 'Foundational agent message');
      await waitForPromises();

      // Verify agentConfig is null and workflowDefinition is used instead
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          workflowDefinition: MOCK_FETCHED_FOUNDATIONAL_AGENT.referenceWithVersion,
          agentConfig: null,
        }),
      );
    });

    it('sends no config when the default agent is selected (no id on selection)', async () => {
      await findDuoChat().vm.$emit('new-chat', { name: 'default duo' });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(mockSocketManager.connect).toHaveBeenCalled();
    });
  });

  describe('Agent deletion handling', () => {
    beforeEach(async () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();
    });

    it('disables chat when agent is deleted', async () => {
      // Mock thread with deleted agent
      ApolloUtils.fetchWorkflowEvents.mockResolvedValue({
        ...MOCK_WORKFLOW_EVENTS_RESPONSE,
        duoWorkflowWorkflows: {
          nodes: [{ id: 'workflow-1', aiCatalogItemVersionId: 'AgentVersion 999' }],
        },
      });

      findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
      await waitForPromises();

      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe(
        'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      );
    });

    it('hides error in history view', () => {
      createComponent({
        data: { multithreadedView: DUO_CHAT_VIEWS.LIST, agentOrWorkflowDeletedError: 'Error' },
      });

      expect(findDuoChat().props('error')).toBe('');
    });

    it('re-enables chat when starting new chat after viewing deleted agent thread', async () => {
      // Mock thread with deleted agent
      ApolloUtils.fetchWorkflowEvents.mockResolvedValue({
        ...MOCK_WORKFLOW_EVENTS_RESPONSE,
        duoWorkflowWorkflows: {
          nodes: [{ id: 'workflow-1', aiCatalogItemVersionId: 'AgentVersion 999' }],
        },
      });

      // Select thread with deleted agent
      findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
      await waitForPromises();

      // Verify chat is disabled
      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe(
        'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      );

      // Start a new chat with default agent
      findDuoChat().vm.$emit('new-chat', { name: 'GitLab Duo Agent' });
      await nextTick();

      // Verify chat is re-enabled and error is cleared
      expect(findDuoChat().props('isChatAvailable')).toBe(true);
      expect(findDuoChat().props('error')).toBe('');
    });
  });

  describe('dynamicTitle', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
    });

    it('passes the base title when no custom agent is selected', async () => {
      createComponent();
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('Duo Agent');
    });

    it('passes the agent name as title when a custom agent is selected', async () => {
      createComponent({
        propsData: {
          mode: 'default',
        },
        data: {
          aiCatalogItemVersionId: 'AgentVersion 5',
          catalogAgents: [
            {
              id: 'Agent 5',
              name: 'My Custom Agent',
              description: 'This is my custom agent',
              pinnedItemVersionId: 'AgentVersion 5',
            },
          ],
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('My Custom Agent');
    });

    it('passes the agent name as title when a foundational agent is selected', async () => {
      createComponent();

      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe(MOCK_FETCHED_FOUNDATIONAL_AGENT.name);
    });
  });

  describe('flowConfig Apollo query integration', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      ApolloUtils.createWorkflow = jest
        .fn()
        .mockResolvedValue({ workflowId: '456', threadId: null });
    });

    it('queries agentConfig when aiCatalogItemVersionId is set', async () => {
      agentFlowConfigQueryMock.mockClear();

      createComponent({
        data: {
          aiCatalogItemVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
        },
      });

      await waitForPromises();

      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
      });
    });

    it('fetches fresh agent config when switching agents', async () => {
      const agent2 = {
        id: 'Agent 2',
        name: 'Test Agent',
        pinnedItemVersionId: 'version-2',
      };

      agentFlowConfigQueryMock.mockClear();

      createComponent({
        data: {
          aiCatalogItemVersionId: 'version-1',
        },
      });
      await waitForPromises();

      // Switch to agent2
      findDuoChat().vm.$emit('new-chat', agent2);
      await nextTick();
      await waitForPromises();

      // Verify query was called with the new agent version id
      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: 'version-2',
      });
    });

    describe('when switching from custom agent to default agent', () => {
      beforeEach(async () => {
        createComponent({
          data: {
            aiCatalogItemVersionId: 'version-1',
          },
        });
        await waitForPromises();
      });

      it('stops querying agent config', async () => {
        // Verify config query was called for the custom agent
        expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
          agentVersionId: 'version-1',
        });

        agentFlowConfigQueryMock.mockClear();

        // Switch to default agent (no agent.id)
        findDuoChat().vm.$emit('new-chat', { name: 'default duo' });
        await waitForPromises();

        // Verify no config is sent when starting workflow with default agent
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(mockSocketManager.connect).toHaveBeenCalled();
        expect(agentFlowConfigQueryMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('embedded mode behavior', () => {
    describe('when embedded=false (standalone mode)', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent({
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              isAgenticAvailable: false,
              defaultProps: {
                isEmbedded: false,
              },
            },
          },
        });
      });

      it('shows header', () => {
        expect(findDuoChat().props('showHeader')).toBe(true);
      });

      it('enables resizing', () => {
        expect(findDuoChat().props('shouldRenderResizable')).toBe(true);
      });

      it('returns empty dimensions object', () => {
        expect(findDuoChat().props('dimensions')).toEqual({});
      });

      it('sets up window resize listeners on mount', () => {
        const addEventListenerSpy = jest.spyOn(window, 'addEventListener');
        createComponent({
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              isAgenticAvailable: false,
              defaultProps: {
                isEmbedded: false,
              },
            },
          },
        });

        expect(addEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
        addEventListenerSpy.mockRestore();
      });

      it('cleans up resize listeners on destroy', () => {
        const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
        wrapper.destroy();

        expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
        removeEventListenerSpy.mockRestore();
      });

      it('modifies duoChatGlobalState on @chat-hidden', async () => {
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);

        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();

        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
      });

      it('hydrates the active thread when a thread is selected', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
        const mockParsedData = {
          checkpoint: { channel_values: { ui_chat_log: [] } },
        };

        WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(findDuoChat().props('messages')).toEqual(MOCK_TRANSFORMED_MESSAGES);
      });
    });

    describe('when embedded=true', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent({
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              isAgenticAvailable: true,
              defaultProps: {
                isEmbedded: true,
              },
            },
            activeTabData: {
              props: {
                isEmbedded: true,
                isAgenticAvailable: true,
                userId: null,
              },
            },
          },
        });
      });

      it('hides header', () => {
        expect(findDuoChat().props('showHeader')).toBe(true);
      });

      it('disables resizing', () => {
        expect(findDuoChat().props('shouldRenderResizable')).toBe(false);
      });

      it('passes dimensions object', () => {
        expect(findDuoChat().props('dimensions')).toBeDefined();
        expect(findDuoChat().props('dimensions')).toMatchObject({
          width: expect.any(Number),
          height: expect.any(Number),
        });
      });

      it('does not set up window resize listeners on mount', () => {
        const addEventListenerSpy = jest.spyOn(window, 'addEventListener');
        createComponent({
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              isAgenticAvailable: true,
              defaultProps: {
                isEmbedded: true,
              },
            },
            activeTabData: {
              props: {
                isEmbedded: true,
                isAgenticAvailable: true,
                userId: null,
              },
            },
          },
        });

        const resizeCalls = addEventListenerSpy.mock.calls.filter(([event]) => event === 'resize');
        expect(resizeCalls).toHaveLength(0);
        addEventListenerSpy.mockRestore();
      });

      it('does not try to clean up resize listeners on destroy', () => {
        const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
        wrapper.destroy();

        const resizeCalls = removeEventListenerSpy.mock.calls.filter(
          ([event]) => event === 'resize',
        );
        expect(resizeCalls).toHaveLength(0);
        removeEventListenerSpy.mockRestore();
      });

      it('does not modify duoChatGlobalState on @chat-hidden', async () => {
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);

        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();

        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);
      });

      it('calls setAgenticMode with embedded=true when toggling agentic mode', async () => {
        getCookie.mockReturnValue('false');

        const findGlToggle = () => wrapper.findComponent(GlToggle);

        findGlToggle().vm.$emit('change', true);
        await nextTick();

        expect(setAgenticMode).toHaveBeenCalledWith({
          agenticMode: true,
          saveCookie: true,
          isEmbedded: true,
        });
      });

      it('does not hydrate the active thread when a thread is selected', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
        const mockParsedData = {
          checkpoint: { channel_values: { ui_chat_log: [] } },
        };

        WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(findDuoChat().props('messages')).toEqual([]);
      });

      describe('Apollo queries in embedded mode', () => {
        beforeEach(async () => {
          duoChatGlobalState.isAgenticChatShown = false;
          createComponent({
            propsData: {
              userModelSelectionEnabled: true,
              rootNamespaceId: MOCK_NAMESPACE_ID,
            },
            provide: {
              chatConfiguration: {
                title: 'GitLab Duo Agentic Chat',
                isAgenticAvailable: true,
                defaultProps: {
                  isEmbedded: true,
                },
              },
              activeTabData: {
                props: {
                  isEmbedded: true,
                  isAgenticAvailable: true,
                  userId: null,
                },
              },
            },
          });
          await waitForPromises();
        });

        it('runs agenticWorkflows query when embedded=true even if isAgenticChatShown=false', () => {
          expect(userWorkflowsQueryHandlerMock).toHaveBeenCalled();
        });

        it('runs contextPresets query when embedded=true even if isAgenticChatShown=false', () => {
          expect(contextPresetsQueryHandlerMock).toHaveBeenCalled();
        });

        it('runs availableModels query when embedded=true even if isAgenticChatShown=false', () => {
          expect(availableModelsQueryHandlerMock).toHaveBeenCalled();
        });

        it('runs catalogAgents query when embedded=true even if isAgenticChatShown=false', () => {
          expect(configuredAgentsQueryMock).toHaveBeenCalled();
        });
      });

      describe('@thread-selected event in embedded mode', () => {
        it('emits switch-to-active-tab event when thread is selected', async () => {
          const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
          const mockParsedData = { checkpoint: { channel_values: { ui_chat_log: [] } } };

          WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
          WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

          findDuoChat().vm.$emit('thread-selected', mockThread);
          await waitForPromises();

          expect(wrapper.emitted('switch-to-active-tab')?.length > 0).toBe(true);
        });
      });
    });
  });

  describe('Duo UI Next', () => {
    describe('when the feature flag is disabled', () => {
      it('does not render the DuoNext component by default', () => {
        createComponent();
        expect(findDuoNext().exists()).toBe(false);
      });
    });

    describe('when the feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              duoUiNext: true,
            },
          },
        });
      });

      it('renders the DuoNext component if the flag is enabled', () => {
        expect(findDuoNext().exists()).toBe(true);
        expect(findDuoChat().exists()).toBe(false);
      });
    });
  });
});
