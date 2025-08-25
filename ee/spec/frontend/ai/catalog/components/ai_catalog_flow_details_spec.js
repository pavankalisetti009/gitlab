import { shallowMount } from '@vue/test-utils';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import { mockFlow, mockFlowVersion } from '../mock_data';

describe('AiCatalogFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
  };

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogFlowDetails, {
      propsData: {
        ...defaultProps,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders item steps', () => {
    expect(wrapper.text()).toContain(mockFlowVersion.steps.nodes[0].agent.name);
  });
});
