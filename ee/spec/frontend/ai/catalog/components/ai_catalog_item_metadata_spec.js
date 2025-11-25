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
  const findCreatedOnItem = () => wrapper.findByTestId('metadata-created-on');
  const findFoundationalItem = () => wrapper.findByTestId('metadata-foundational');
  const findModifiedItem = () => wrapper.findByTestId('metadata-modified');

  beforeEach(() => {
    createComponent();
  });

  describe('date fields', () => {
    it('should be displayed with correct icons when provided', () => {
      const listItems = findAllListItems();
      expect(listItems).toHaveLength(2);

      const createdOn = findCreatedOnItem();
      expect(createdOn.exists()).toBe(true);
      expect(createdOn.text()).toContain('Created on January 15, 2024');
      expect(createdOn.findComponent(GlIcon).props('name')).toBe('calendar');

      const modified = findModifiedItem();
      expect(modified.text()).toContain('Modified Aug 21, 2025');
      expect(modified.findComponent(GlIcon).props('name')).toBe('clock');
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

      expect(findCreatedOnItem().text()).toContain('Created');
      expect(findModifiedItem().exists()).toBe(false);
    });
  });

  describe('foundational agent metadata', () => {
    beforeEach(() => {
      createComponent({
        item: {
          ...mockAgent,
          foundationalChat: true,
        },
      });
    });

    it('displays foundational metadata when item is foundational', () => {
      const listItems = findAllListItems();
      expect(listItems).toHaveLength(3);

      const foundational = findFoundationalItem();
      expect(foundational.text()).toContain('Foundational agent');
      expect(foundational.findComponent(GlIcon).props('name')).toBe('tanuki-verified');
    });

    it('does not display foundational metadata when item is not foundational', () => {
      createComponent({
        item: {
          ...mockAgent,
          foundationalChat: false,
        },
      });

      expect(findFoundationalItem().exists()).toBe(false);
    });
  });
});
