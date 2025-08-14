import { shallowMount } from '@vue/test-utils';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import { mockAgent, mockAgentVersion } from '../mock_data';

const TOOLS = ['A Tool', 'Another Tool'];

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  const defaultProps = {
    item: {
      ...mockAgent,
      latestVersion: {
        ...mockAgentVersion,
        tools: {
          nodes: TOOLS.map((t) => ({ title: t })),
        },
      },
    },
  };

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogAgentDetails, {
      propsData: {
        ...defaultProps,
      },
    });
  };

  const findAllDetails = () => wrapper.findAll('dd');

  beforeEach(() => {
    createComponent();
  });

  it('renders system and user prompts', () => {
    expect(findAllDetails().at(0).text()).toBe(mockAgent.latestVersion.systemPrompt);
    expect(findAllDetails().at(1).text()).toBe(mockAgent.latestVersion.userPrompt);
    expect(findAllDetails().at(2).text()).toBe(TOOLS.join(', '));
  });
});
