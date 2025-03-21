import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableFilteredSearchBar from 'ee/geo_replicable/components/geo_replicable_filtered_search_bar.vue';
import { getReplicableTypeFilter } from 'ee/geo_replicable/filters';
import { MOCK_REPLICABLE_TYPES, MOCK_REPLICABLE_TYPE_FILTER } from '../mock_data';

describe('GeoReplicableFilteredSearchBar', () => {
  let wrapper;

  const defaultProps = {
    activeFilters: [MOCK_REPLICABLE_TYPE_FILTER],
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableFilteredSearchBar, {
      propsData,
      provide: {
        replicableTypes: MOCK_REPLICABLE_TYPES,
      },
    });
  };

  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('Replicable type listbox', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with the correct selected filter', () => {
      expect(findCollapsibleListbox().props('selected')).toBe(MOCK_REPLICABLE_TYPE_FILTER.value);
    });

    it('renders with the formatted options', () => {
      const expectedItems = MOCK_REPLICABLE_TYPES.map((type) => ({
        text: type.titlePlural,
        value: type.namePlural,
      }));
      expect(findCollapsibleListbox().props('items')).toStrictEqual(expectedItems);
    });

    it('on search updates the items retaining the selected item', async () => {
      const mockSearch = MOCK_REPLICABLE_TYPES[0].titlePlural;
      const formattedItems = MOCK_REPLICABLE_TYPES.map((type) => ({
        text: type.titlePlural,
        value: type.namePlural,
      }));
      const expectedSearchedItems = formattedItems.filter(
        (item) => item.value === MOCK_REPLICABLE_TYPE_FILTER.value || item.text === mockSearch,
      );

      findCollapsibleListbox().vm.$emit('search', mockSearch);
      await nextTick();

      expect(findCollapsibleListbox().props('items')).toStrictEqual(expectedSearchedItems);
    });

    it('on select emits search to the parent with the replicable type filter', async () => {
      findCollapsibleListbox().vm.$emit('select', MOCK_REPLICABLE_TYPES[0].namePlural);
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([
        [[getReplicableTypeFilter(MOCK_REPLICABLE_TYPES[0].namePlural)]],
      ]);
    });
  });
});
