// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import Vue from 'vue';
import { GlAvatar } from '@gitlab/ui';
import { DuoChatPredefinedPrompts } from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ActiveTrialOrSubscriptionEmptyState from 'ee/ai/duo_agentic_chat/components/active_trial_or_subscription_empty_state.vue';

Vue.use(Vuex);

describe('ActiveTrialOrSubscriptionEmptyState', () => {
  let wrapper;
  let store;

  const mockAgents = [
    { id: 'agent-1', name: 'Agent 1', avatarUrl: 'avatar1.png' },
    { id: 'agent-2', name: 'Agent 2', avatarUrl: 'avatar2.png' },
    { id: 'agent-3', name: 'Agent 3', avatarUrl: 'avatar3.png' },
  ];

  const mockPrompts = [
    { id: 'prompt-1', title: 'Prompt 1' },
    { id: 'prompt-2', title: 'Prompt 2' },
  ];

  const defaultProps = {
    agents: mockAgents,
    predefinedPrompts: mockPrompts,
    exploreAiCatalogPath: '/explore-agents',
  };

  const createComponent = (props = {}) => {
    store = new Vuex.Store({
      state: {
        currentAgent: { id: 'gid://gitlab/Ai::FoundationalChatAgent/chat' },
      },
      mutations: {},
      actions: {
        setCurrentAgent: jest.fn(),
      },
    });

    wrapper = shallowMountExtended(ActiveTrialOrSubscriptionEmptyState, {
      propsData: { ...defaultProps, ...props },
      store,
    });
  };

  const findImage = () => wrapper.find('img');
  const findHeading = () => wrapper.find('h2');
  const findAgentLinks = () => wrapper.findAllByTestId('agent-link');
  const findPredefinedPrompts = () => wrapper.findComponent(DuoChatPredefinedPrompts);
  const findExploreLink = () => wrapper.findByTestId('explore-agents-link');
  const findAgentAvatars = () => wrapper.findAllComponents(GlAvatar);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the image', () => {
      expect(findImage().exists()).toBe(true);
    });

    it('renders the heading', () => {
      expect(findHeading().exists()).toBe(true);
    });

    it('renders predefined prompts component', () => {
      expect(findPredefinedPrompts().exists()).toBe(true);
    });

    it('renders suggested agents', () => {
      expect(findAgentAvatars()).toHaveLength(2);
    });

    it('renders explore agents link', () => {
      expect(findExploreLink().exists()).toBe(true);
    });
  });

  describe('suggested agents', () => {
    it('renders up to 2 suggested agents', () => {
      createComponent();

      expect(findAgentLinks()).toHaveLength(2);
    });

    it('displays agent names and avatars', () => {
      createComponent();

      const links = findAgentLinks();
      expect(links.at(0).text()).toContain('Agent 1');
      expect(links.at(1).text()).toContain('Agent 2');
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits "send-chat-prompt" when predefined prompt is clicked', () => {
      const prompt = mockPrompts[0];
      findPredefinedPrompts().vm.$emit('click', prompt);

      expect(wrapper.emitted('send-chat-prompt')).toHaveLength(1);
      expect(wrapper.emitted('send-chat-prompt')[0][0]).toEqual(prompt);
    });

    it('emits "new-chat" when agent is clicked', () => {
      const agent = mockAgents[0];
      wrapper.vm.handleAgentClick(agent);

      expect(wrapper.emitted('new-chat')).toHaveLength(1);
      expect(wrapper.emitted('new-chat')[0][0]).toEqual(agent);
    });
  });
});
