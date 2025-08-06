import { shallowMount } from '@vue/test-utils';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import { mockAgent } from '../mock_data';

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockAgent,
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
  });
});
