import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import GeoReplicableApp from 'ee/geo_replicable/components/app.vue';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoReplicableEmptyState from 'ee/geo_replicable/components/geo_replicable_empty_state.vue';
import GeoReplicableFilterBar from 'ee/geo_replicable/components/geo_replicable_filter_bar.vue';
import GeoReplicableFilteredSearchBar from 'ee/geo_replicable/components/geo_replicable_filtered_search_bar.vue';
import initStore from 'ee/geo_replicable/store';
import { TEST_HOST } from 'spec/test_constants';
import {
  MOCK_GEO_REPLICATION_SVG_PATH,
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_GRAPHQL_REGISTRY,
  MOCK_REPLICABLE_TYPE_FILTER,
} from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableApp', () => {
  let wrapper;
  let store;

  const propsData = {
    geoReplicableEmptySvgPath: MOCK_GEO_REPLICATION_SVG_PATH,
  };

  const createStore = (options) => {
    store = initStore({ replicableType: MOCK_REPLICABLE_TYPE, ...options });
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = ({ featureFlags = {} } = {}) => {
    wrapper = shallowMount(GeoReplicableApp, {
      store,
      propsData,
      provide: {
        glFeatures: { ...featureFlags },
      },
    });
  };

  const findGeoReplicableContainer = () => wrapper.find('.geo-replicable-container');
  const findGlLoadingIcon = () => findGeoReplicableContainer().findComponent(GlLoadingIcon);
  const findGeoReplicable = () => findGeoReplicableContainer().findComponent(GeoReplicable);
  const findGeoReplicableEmptyState = () =>
    findGeoReplicableContainer().findComponent(GeoReplicableEmptyState);
  const findGeoReplicableFilterBar = () =>
    findGeoReplicableContainer().findComponent(GeoReplicableFilterBar);
  const findGeoReplicableFilteredSearchBar = () =>
    findGeoReplicableContainer().findComponent(GeoReplicableFilteredSearchBar);

  describe.each`
    isLoading | graphqlFieldName         | replicableItems            | showReplicableItems | showEmptyState | showLoader
    ${false}  | ${null}                  | ${MOCK_BASIC_GRAPHQL_DATA} | ${true}             | ${false}       | ${false}
    ${false}  | ${null}                  | ${[]}                      | ${false}            | ${true}        | ${false}
    ${false}  | ${MOCK_GRAPHQL_REGISTRY} | ${MOCK_BASIC_GRAPHQL_DATA} | ${true}             | ${false}       | ${false}
    ${false}  | ${MOCK_GRAPHQL_REGISTRY} | ${[]}                      | ${false}            | ${true}        | ${false}
    ${true}   | ${null}                  | ${MOCK_BASIC_GRAPHQL_DATA} | ${false}            | ${false}       | ${true}
    ${true}   | ${null}                  | ${[]}                      | ${false}            | ${false}       | ${true}
    ${true}   | ${MOCK_GRAPHQL_REGISTRY} | ${MOCK_BASIC_GRAPHQL_DATA} | ${false}            | ${false}       | ${true}
    ${true}   | ${MOCK_GRAPHQL_REGISTRY} | ${[]}                      | ${false}            | ${false}       | ${true}
  `(
    `template`,
    ({
      isLoading,
      graphqlFieldName,
      replicableItems,
      showReplicableItems,
      showEmptyState,
      showLoader,
    }) => {
      beforeEach(() => {
        createStore({ graphqlFieldName });
        createComponent();
      });

      describe(`when isLoading is ${isLoading} and graphqlFieldName is ${graphqlFieldName}, ${
        replicableItems.length ? 'with' : 'without'
      } replicableItems`, () => {
        beforeEach(() => {
          store.state.isLoading = isLoading;
          store.state.replicableItems = replicableItems;
          store.state.paginationData.total = replicableItems.length;
        });

        it(`${showReplicableItems ? 'shows' : 'hides'} the replicable items`, () => {
          expect(findGeoReplicable().exists()).toBe(showReplicableItems);
        });

        it(`${showEmptyState ? 'shows' : 'hides'} the empty state`, () => {
          expect(findGeoReplicableEmptyState().exists()).toBe(showEmptyState);
        });

        it(`${showLoader ? 'shows' : 'hides'} the loader`, () => {
          expect(findGlLoadingIcon().exists()).toBe(showLoader);
        });
      });
    },
  );

  describe('filter bar', () => {
    describe('when feature geoReplicablesFilteredListView is disabled', () => {
      beforeEach(() => {
        createStore();
        createComponent({ featureFlags: { geoReplicablesFilteredListView: false } });
      });

      it('renders filter bar', () => {
        expect(findGeoReplicableFilterBar().exists()).toBe(true);
      });

      it('does not render filtered search bar', () => {
        expect(findGeoReplicableFilteredSearchBar().exists()).toBe(false);
      });
    });

    describe('when feature geoReplicablesFilteredListView is enabled', () => {
      const originalHref = window.location.href;

      beforeEach(() => {
        Object.defineProperty(window, 'location', {
          writable: true,
          value: {
            href: `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}`,
          },
        });

        createStore();
        createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
      });

      afterEach(() => {
        Object.defineProperty(window, 'location', {
          writable: true,
          value: { href: originalHref },
        });
      });

      it('does not render filter bar', () => {
        expect(findGeoReplicableFilterBar().exists()).toBe(false);
      });

      it('renders filtered search bar with active filters', () => {
        expect(findGeoReplicableFilteredSearchBar().props('activeFilters')).toStrictEqual([
          MOCK_REPLICABLE_TYPE_FILTER,
        ]);
      });
    });
  });

  describe('onCreate', () => {
    beforeEach(() => {
      createStore();
      createComponent();
    });

    it('calls fetchReplicableItems', () => {
      expect(store.dispatch).toHaveBeenCalledWith('fetchReplicableItems');
    });
  });
});
