import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import AiCatalogItemMetadata from 'ee/ai/catalog/components/ai_catalog_item_metadata.vue';
import { mockAgent } from '../mock_data';

describe('AiCatalogItemMetadata', () => {
  let wrapper;

  const GlIconStub = stubComponent(GlIcon);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemMetadata, {
      propsData: {
        item: mockAgent,
        ...props,
      },
      stubs: {
        GlIcon: GlIconStub,
      },
    });
  };

  const findAllListItems = () => wrapper.findAll('li');

  beforeEach(() => {
    createComponent();
  });

  describe('date fields', () => {
    it('should be displayed with correct icons when provided', () => {
      const listItems = findAllListItems();
      expect(listItems).toHaveLength(2);
      expect(listItems.at(0).text()).toContain('Created on January 15, 2024');
      expect(listItems.at(1).text()).toContain('Modified Aug 21, 2025');

      const icons = wrapper.findAllComponents(GlIcon);
      expect(icons).toHaveLength(2);
      expect(icons.at(0).props('name')).toBe('calendar');
      expect(icons.at(1).props('name')).toBe('clock');
    });

    it('should have createdAt but not updatedAt when these fields match', () => {
      const mockCreatedAt = mockAgent.createdAt;
      createComponent({
        item: {
          ...mockAgent,
          updatedAt: mockCreatedAt,
          latestVersion: { updatedAt: mockCreatedAt },
        },
      });

      const listItems = findAllListItems();
      expect(listItems).toHaveLength(1);
      expect(listItems.at(0).text()).toContain('Created');
      expect(wrapper.text()).not.toContain('Modified');
    });
  });
});
