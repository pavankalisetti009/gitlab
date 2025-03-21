import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableFilteredSearchBar from 'ee/geo_replicable/components/geo_replicable_filtered_search_bar.vue';
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

  const findActiveFilters = () => wrapper.findByTestId('active-filters');
  const findActiveReplicableType = () => wrapper.findByTestId('active-replicable-type');

  describe('Replicable type listbox', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with the correct active filters', () => {
      expect(findActiveFilters().text().replace(/\s+/g, '')).toBe(
        JSON.stringify([MOCK_REPLICABLE_TYPE_FILTER]),
      );
    });

    it('renders with the correct active replicable type', () => {
      expect(findActiveReplicableType().text()).toBe(MOCK_REPLICABLE_TYPE_FILTER.value);
    });
  });
});
