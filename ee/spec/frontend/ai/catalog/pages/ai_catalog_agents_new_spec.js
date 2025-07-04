import { shallowMount } from '@vue/test-utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';

describe('AiCatalogAgentsNew', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogAgentsNew);
  };

  const findHeader = () => wrapper.findComponent(PageHeading);

  describe('component initialization', () => {
    it('renders the page heading', async () => {
      await createComponent();

      expect(findHeader().props('heading')).toBe('Create new agent');
    });
  });
});
