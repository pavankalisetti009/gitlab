import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';

describe('AiCatalogListHeader', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListHeader, {
      propsData: {
        ...props,
      },
      provide: {
        isGlobal: true,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders default title', () => {
    expect(findPageHeading().text()).toBe('AI Catalog');
  });

  it('renders AiCatalogNavTabs component', () => {
    expect(wrapper.findComponent(AiCatalogNavTabs).exists()).toBe(true);
  });

  it('renders AiCatalogNavActions component', () => {
    expect(wrapper.findComponent(AiCatalogNavActions).exists()).toBe(true);
  });

  describe('when isGlobal is false', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isGlobal: false,
        },
      });
    });

    it('does not renders AiCatalogNavTabs component', () => {
      expect(wrapper.findComponent(AiCatalogNavTabs).exists()).toBe(false);
    });

    it('renders AiCatalogNavActions component', () => {
      expect(wrapper.findComponent(AiCatalogNavActions).exists()).toBe(true);
    });
  });

  describe('when heading prop is passed', () => {
    beforeEach(() => {
      createComponent({ props: { heading: 'Custom title' } });
    });

    it('renders provided title', () => {
      expect(findPageHeading().text()).toContain('Custom title');
    });
  });
});
