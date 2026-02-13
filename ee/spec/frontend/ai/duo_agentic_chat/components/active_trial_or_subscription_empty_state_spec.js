// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import Vue from 'vue';
import { GlAvatar } from '@gitlab/ui';
import { DuoChatPredefinedPrompts } from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ActiveTrialOrSubscriptionEmptyState from 'ee/ai/duo_agentic_chat/components/active_trial_or_subscription_empty_state.vue';
import {
  TRACKING_EVENT_VIEW_EMPTY_STATE,
  TRACKING_EVENT_CLICK_AGENT,
  TRACKING_EVENT_CLICK_PROMPT,
  TRACKING_EVENT_CLICK_EXPLORE_AGENTS,
} from 'ee/ai/duo_agentic_chat/constants';

Vue.use(Vuex);

describe('ActiveTrialOrSubscriptionEmptyState', () => {
  let wrapper;
  let store;

  const mockAgents = [
    { id: 'agent-1', name: 'Agent 1', avatarUrl: 'avatar1.png' },
    { id: 'agent-2', name: 'Agent 2', avatarUrl: 'avatar2.png' },
    { id: 'agent-3', name: 'Agent 3', avatarUrl: 'avatar3.png' },
  ];

  const mockPrompts = ['Prompt 1', 'Prompt 2'];

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
      findPredefinedPrompts().vm.$emit('click', mockPrompts[0]);

      expect(wrapper.emitted('send-chat-prompt')).toHaveLength(1);
      expect(wrapper.emitted('send-chat-prompt')[0][0]).toEqual(mockPrompts[0]);
    });

    it('emits "new-chat" when agent is clicked', () => {
      const agent = mockAgents[0];
      wrapper.vm.handleAgentClick(agent);

      expect(wrapper.emitted('new-chat')).toHaveLength(1);
      expect(wrapper.emitted('new-chat')[0][0]).toEqual(agent);
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks view event on mount', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(TRACKING_EVENT_VIEW_EMPTY_STATE, {}, undefined);
    });

    it('tracks prompt click with label', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      const prompt = mockPrompts[0];
      findPredefinedPrompts().vm.$emit('click', prompt);

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_PROMPT,
        { label: 'Prompt 1' },
        undefined,
      );
    });

    it('tracks agent click with label', async () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findAgentLinks().at(0).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_AGENT,
        { label: 'Agent 1' },
        undefined,
      );
    });

    it('tracks explore agents link click', async () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findExploreLink().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_EXPLORE_AGENTS,
        {},
        undefined,
      );
    });
  });
});
