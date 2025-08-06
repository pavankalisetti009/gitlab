import { shallowMount } from '@vue/test-utils';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import { mockFlow } from '../mock_data';

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

  it('renders item', () => {
    expect(wrapper.text()).toContain(mockFlow.name);
  });
});
