import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlDisclosureDropdown } from '@gitlab/ui';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import NewChatButton from 'ee/ai/components/new_chat_button.vue';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';

import {
  MOCK_CONFIGURED_AGENTS_RESPONSE,
  MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
} from '../duo_agentic_chat/components/mock_data';

const disabledTooltipText = 'An administrator has turned off GitLab Duo for this project.';

Vue.use(VueApollo);

describe('NewChatButton', () => {
  let wrapper;

  const configuredAgentsQueryMock = jest.fn().mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
  const aiFoundationalChatAgentsQueryMock = jest
    .fn()
    .mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);

  const createComponent = async ({
    activeTab = 'chat',
    isExpanded = true,
    showSuggestionsTab = true,
    chatDisabledReason = '',
    isChatDisabled = false,
    chatDisabledTooltip = '',
    isAgentSelectEnabled = true,
  } = {}) => {
    const apolloProvider = createMockApollo([
      [getConfiguredAgents, configuredAgentsQueryMock],
      [getFoundationalChatAgents, aiFoundationalChatAgentsQueryMock],
    ]);

    wrapper = shallowMountExtended(NewChatButton, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        activeTab,
        isExpanded,
        showSuggestionsTab,
        chatDisabledReason,
        isChatDisabled,
        chatDisabledTooltip,
        isAgentSelectEnabled,
      },
      stubs: {
        GlButton,
      },
    });

    await waitForPromises();
  };

  const findNewToggle = () => wrapper.findByTestId('ai-new-toggle');
  const findAgentDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

  describe('when there are multiple agents', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders dropdown instead of button', () => {
      expect(findAgentDropdown().exists()).toBe(true);
      expect(findNewToggle().exists()).toBe(false);
    });

    describe('when an agent is selected', () => {
      const mockAgent = {
        id: 'gid://gitlab/Ai::FoundationalChatAgent/chat',
        name: 'GitLab Duo Agent',
        description: 'Duo is your general development assistant',
      };

      beforeEach(async () => {
        findAgentDropdown().vm.$emit('action', mockAgent);
        await nextTick();
      });

      it('emits new-chat event with the agent as payload', () => {
        expect(wrapper.emitted('new-chat')).toEqual([[mockAgent]]);
      });
    });
  });

  describe('when there is only one agent or no agents', () => {
    beforeEach(async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: { aiFoundationalChatAgents: { nodes: [] } },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent();
    });

    it('renders button instead of dropdown', () => {
      expect(findNewToggle().exists()).toBe(true);
      expect(findAgentDropdown().exists()).toBe(false);
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        await findNewToggle().trigger('click');
      });

      it('emits new-chat event', () => {
        expect(wrapper.emitted('new-chat')).toHaveLength(1);
      });
    });
  });

  describe('when Apollo queries fail', () => {
    describe('for catalog agents query', () => {
      const error = new Error('Catalog agents query failed');

      beforeEach(async () => {
        configuredAgentsQueryMock.mockRejectedValueOnce(error);

        await createComponent();
      });

      it('emits newChatError with error payload', () => {
        expect(wrapper.emitted('newChatError')).toEqual([[error]]);
      });
    });

    describe('for foundational agents query error', () => {
      const error = new Error('Foundational agents query failed');

      beforeEach(async () => {
        aiFoundationalChatAgentsQueryMock.mockRejectedValue(error);

        await createComponent();
      });

      it('emits newChatError wutg error payload', () => {
        expect(wrapper.emitted('newChatError')).toEqual([[error]]);
      });
    });
  });

  describe('when chat is disabled', () => {
    beforeEach(async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: { aiFoundationalChatAgents: { nodes: [] } },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent({ isChatDisabled: true, chatDisabledTooltip: disabledTooltipText });
    });

    it('sets aria-disabled', () => {
      expect(findNewToggle().attributes('aria-disabled')).toBe('true');
      expect(findNewToggle().classes()).toContain('gl-opacity-5');
    });

    it('shows disabled tooltip', () => {
      expect(findNewToggle().attributes('title')).toBe(disabledTooltipText);
    });
  });

  describe('when isAgentSelectEnabled is false', () => {
    beforeEach(async () => {
      await createComponent({ isAgentSelectEnabled: false });
    });

    it('renders button instead of dropdown', () => {
      expect(findNewToggle().exists()).toBe(true);
      expect(findAgentDropdown().exists()).toBe(false);
    });

    it('does not call Apollo queries', () => {
      expect(configuredAgentsQueryMock).not.toHaveBeenCalled();
      expect(aiFoundationalChatAgentsQueryMock).not.toHaveBeenCalled();
    });

    describe('and button is clicked', () => {
      beforeEach(async () => {
        await findNewToggle().trigger('click');
      });

      it('emits new-chat event', () => {
        expect(wrapper.emitted('new-chat')).toHaveLength(1);
      });
    });
  });
});
