import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogApp from 'ee/ai/catalog/ai_catalog_app.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';

describe('AiCatalogApp', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };

  beforeEach(() => {
    wrapper = shallowMountExtended(AiCatalogApp, {
      mocks: {
        $router: mockRouter,
      },
      stubs: {
        'router-view': true,
      },
    });
  });

  it('renders AiCatalogNavActions component', () => {
    expect(wrapper.findComponent(AiCatalogNavActions).exists()).toBe(true);
  });
});
