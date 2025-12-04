import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import AiCatalogItemMetadata from 'ee/ai/catalog/components/ai_catalog_item_metadata.vue';
import { mockAgent, mockAgentPinnedVersion } from '../mock_data';

describe('AiCatalogItemMetadata', () => {
  let wrapper;

  const GlIconStub = stubComponent(GlIcon);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemMetadata, {
      propsData: {
        item: mockAgent,
        versionData: mockAgentPinnedVersion,
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
  const findVersionItem = () => wrapper.findByTestId('metadata-version');

  beforeEach(() => {
    createComponent();
  });

  describe('number of fields', () => {
    it('should display the correct number of metadata tags', () => {
      // Create a component with *all available* tags.
      // This will fail if we add or remove tags but forget to add/update our tests here.
      createComponent({
        versionData: {
          ...mockAgentPinnedVersion,
          humanVersionName: 'v0.9.0', // version
        },
        item: {
          ...mockAgent,
          createdAt: '2024-01-15T00:00:00Z',
          updatedAt: '2025-08-21T00:00:00Z',
          foundational: true,
        },
      });

      const listItems = findAllListItems();
      expect(listItems).toHaveLength(4);
    });
  });

  describe('date fields', () => {
    it('should be displayed with correct icons when provided', () => {
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

      expect(findCreatedOnItem().text()).toContain('Created');
      expect(findModifiedItem().exists()).toBe(false);
    });
  });

  describe('foundational agent metadata', () => {
    beforeEach(() => {
      createComponent({
        item: {
          ...mockAgent,
          foundational: true,
        },
      });
    });

    it('displays foundational metadata when item is foundational', () => {
      const foundational = findFoundationalItem();
      expect(foundational.text()).toContain('Foundational agent');
      expect(foundational.findComponent(GlIcon).props('name')).toBe('tanuki-verified');
    });

    it('does not display foundational metadata when item is not foundational', () => {
      createComponent({
        item: {
          ...mockAgent,
          foundational: false,
        },
      });

      expect(findFoundationalItem().exists()).toBe(false);
    });
  });

  describe('version field', () => {
    it('should show the human-readable version with correct value and icon', () => {
      const version = findVersionItem();
      expect(version.exists()).toBe(true);
      expect(version.findComponent(GlIcon).props('name')).toBe('tag');
      expect(version.text()).toContain('v0.9.0');
    });
  });
});
