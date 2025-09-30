import { shallowMount } from '@vue/test-utils';
import AiAgentsNew from 'ee/ai/duo_agents_platform/pages/agents/ai_agents_new.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('AiAgentsNew', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);

  const createComponent = ({ aiCatalogFlows = false } = {}) => {
    wrapper = shallowMount(AiAgentsNew, {
      provide: {
        glFeatures: {
          aiCatalogFlows,
        },
      },
    });
  };

  describe('Rendering', () => {
    it('renders the correct description text when aiCatalogFlows feature flag is enabled', () => {
      createComponent({ aiCatalogFlows: true });

      expect(findPageHeading().text()).toContain('Use agents in flows and with GitLab Duo Chat.');
    });

    it('renders the correct description text when aiCatalogFlows feature flag is disabled', () => {
      createComponent({ aiCatalogFlows: false });

      expect(findPageHeading().text()).toContain(
        'Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
      );
    });
  });
});
