import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';

describe('AiCatalogListHeader', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(AiCatalogListHeader);
  });

  it('renders AiCatalogNavTabs component', () => {
    expect(wrapper.findComponent(AiCatalogNavTabs).exists()).toBe(true);
  });

  it('renders AiCatalogNavActions component', () => {
    expect(wrapper.findComponent(AiCatalogNavActions).exists()).toBe(true);
  });
});
