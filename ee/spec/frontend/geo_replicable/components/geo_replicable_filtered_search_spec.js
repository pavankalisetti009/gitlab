import { GlFilteredSearch } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableFilteredSearch from 'ee/geo_replicable/components/geo_replicable_filtered_search.vue';
import {
  FILTERED_SEARCH_TOKEN_DEFINITIONS,
  REPLICATION_STATUS_STATES_ARRAY,
} from 'ee/geo_replicable/constants';
import { MOCK_REPLICATION_STATUS_FILTER } from '../mock_data';

describe('GeoReplicableFilteredSearch', () => {
  let wrapper;

  const defaultProps = {
    activeFilters: [MOCK_REPLICATION_STATUS_FILTER],
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableFilteredSearch, {
      propsData,
    });
  };

  const findGlFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with active filters', () => {
      expect(findGlFilteredSearch().props('value')).toStrictEqual([MOCK_REPLICATION_STATUS_FILTER]);
    });

    it('renders with formatted tokens', () => {
      const expectedTokens = [
        { ...FILTERED_SEARCH_TOKEN_DEFINITIONS[0], options: REPLICATION_STATUS_STATES_ARRAY },
      ];

      expect(findGlFilteredSearch().props('availableTokens')).toStrictEqual(expectedTokens);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('on submit event emits search to the parent with the passed arguments', async () => {
      findGlFilteredSearch().vm.$emit('submit', [MOCK_REPLICATION_STATUS_FILTER]);
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([[[MOCK_REPLICATION_STATUS_FILTER]]]);
    });
  });
});
