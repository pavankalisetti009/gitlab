import { GlButton } from '@gitlab/ui';
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
      },
      stubs: {
        GlButton,
      },
    });

    await waitForPromises();
  };

  const findNewToggle = () => wrapper.findByTestId('ai-new-toggle');

  describe('when chat is disabled', () => {
    beforeEach(() => {
      createComponent({ isChatDisabled: true, chatDisabledTooltip: disabledTooltipText });
    });

    it('sets aria-disabled', () => {
      expect(findNewToggle().attributes('aria-disabled')).toBe('true');
      expect(findNewToggle().classes()).toContain('gl-opacity-5');
    });

    it('prevents tab toggle when clicking disabled buttons', async () => {
      await findNewToggle().trigger('click');

      expect(wrapper.emitted('handleTabToggle')).toBeUndefined();
    });

    it('shows disabled tooltip', () => {
      expect(findNewToggle().attributes('title')).toBe(disabledTooltipText);
    });
  });
});
