import { shallowMount } from '@vue/test-utils';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import AiCatalogItemMetadata from 'ee/ai/catalog/components/ai_catalog_item_metadata.vue';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import { mockAgent, mockFlow, mockThirdPartyFlow } from '../mock_data';

describe('AiCatalogItemView', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AiCatalogItemView, {
      propsData: {
        ...props,
      },
    });
  };

  const findMetadataComponent = () => wrapper.findComponent(AiCatalogItemMetadata);
  const findAgentDetails = () => wrapper.findComponent(AiCatalogAgentDetails);
  const findFlowDetails = () => wrapper.findComponent(AiCatalogFlowDetails);

  describe.each`
    itemType              | item                  | shouldRenderAgent | shouldRenderFlow
    ${'agent'}            | ${mockAgent}          | ${true}           | ${false}
    ${'flow'}             | ${mockFlow}           | ${false}          | ${true}
    ${'third-party flow'} | ${mockThirdPartyFlow} | ${false}          | ${true}
  `('when item is a $itemType', ({ item, shouldRenderAgent, shouldRenderFlow }) => {
    beforeEach(() => {
      createComponent({
        props: { item },
      });
    });

    it(`${shouldRenderAgent ? 'renders' : 'does not render'} AiCatalogAgentDetails component`, () => {
      if (shouldRenderAgent) {
        expect(findAgentDetails().props('item')).toEqual(item);
      } else {
        expect(findAgentDetails().exists()).toBe(false);
      }
    });

    it(`${shouldRenderFlow ? 'renders' : 'does not render'} AiCatalogFlowDetails component`, () => {
      if (shouldRenderFlow) {
        expect(findFlowDetails().props('item')).toEqual(item);
      } else {
        expect(findFlowDetails().exists()).toBe(false);
      }
    });

    it('renders AiCatalogItemMetadata component', () => {
      expect(findMetadataComponent().props('item')).toEqual(item);
    });
  });
});
