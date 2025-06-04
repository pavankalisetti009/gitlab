import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { BULK_ACTIONS } from 'ee/geo_replicable/constants';
import GeoFeedbackBanner from 'ee/geo_replicable/components/geo_feedback_banner.vue';
import GeoReplicableApp from 'ee/geo_replicable/components/app.vue';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoReplicableEmptyState from 'ee/geo_replicable/components/geo_replicable_empty_state.vue';
import GeoReplicableFilterBar from 'ee/geo_replicable/components/geo_replicable_filter_bar.vue';
import GeoListFilteredSearchBar from 'ee/geo_shared/list/components/geo_list_filtered_search_bar.vue';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import initStore from 'ee/geo_replicable/store';
import { processFilters } from 'ee/geo_replicable/filters';
import { TEST_HOST } from 'spec/test_constants';
import setWindowLocation from 'helpers/set_window_location_helper';
import { setUrlParams, visitUrl } from '~/lib/utils/url_utility';
import {
  MOCK_GEO_REPLICATION_SVG_PATH,
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_GRAPHQL_REGISTRY,
  MOCK_REPLICABLE_TYPE_FILTER,
  MOCK_REPLICATION_STATUS_FILTER,
} from '../mock_data';

const MOCK_FILTERS = { foo: 'bar' };
const MOCK_PROCESSED_FILTERS = { query: MOCK_FILTERS, url: { href: 'mock-url/params' } };
const MOCK_UPDATED_URL = 'mock-url/params?foo=bar';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  setUrlParams: jest.fn(() => MOCK_UPDATED_URL),
  visitUrl: jest.fn(),
}));

jest.mock('ee/geo_replicable/filters', () => ({
  ...jest.requireActual('ee/geo_replicable/filters'),
  processFilters: jest.fn(() => MOCK_PROCESSED_FILTERS),
}));

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
  const findGeoListFilteredSearchBar = () =>
    findGeoReplicableContainer().findComponent(GeoListFilteredSearchBar);
  const findGeoListBulkActions = () =>
    findGeoReplicableContainer().findComponent(GeoListBulkActions);
  const findGeoFeedbackBanner = () => wrapper.findComponent(GeoFeedbackBanner);

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
        expect(findGeoListFilteredSearchBar().exists()).toBe(false);
      });
    });

    describe('when feature geoReplicablesFilteredListView is enabled', () => {
      describe('when no query is present', () => {
        beforeEach(() => {
          setWindowLocation(
            `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}`,
          );

          createStore();
          createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
        });

        it('does not render filter bar', () => {
          expect(findGeoReplicableFilterBar().exists()).toBe(false);
        });

        it('renders filtered search bar with correct listbox item and no search filters', () => {
          expect(findGeoListFilteredSearchBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListFilteredSearchBar().props('activeFilteredSearchFilters')).toStrictEqual(
            [],
          );
        });
      });

      describe('when query is present', () => {
        beforeEach(() => {
          setWindowLocation(
            `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}?${MOCK_REPLICATION_STATUS_FILTER.type}=${MOCK_REPLICATION_STATUS_FILTER.value.data}`,
          );

          createStore();
          createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
        });

        it('does not render filter bar', () => {
          expect(findGeoReplicableFilterBar().exists()).toBe(false);
        });

        it('renders filtered search bar with correct listbox item and search filters', () => {
          expect(findGeoListFilteredSearchBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListFilteredSearchBar().props('activeFilteredSearchFilters')).toStrictEqual(
            [MOCK_REPLICATION_STATUS_FILTER],
          );
        });
      });
    });
  });

  describe('bulk actions', () => {
    describe('when feature geoReplicablesFilteredListView is disabled', () => {
      beforeEach(() => {
        createStore();
        createComponent({ featureFlags: { geoReplicablesFilteredListView: false } });
        store.state.replicableItems = MOCK_BASIC_GRAPHQL_DATA;
      });

      it('does not render bulk actions', () => {
        expect(findGeoListBulkActions().exists()).toBe(false);
      });
    });

    describe('when feature geoReplicablesFilteredListView is enabled', () => {
      beforeEach(() => {
        createStore();
        createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
      });

      describe('with no replicable items', () => {
        beforeEach(() => {
          store.state.replicableItems = [];
        });

        it('does not render bulk actions', () => {
          expect(findGeoListBulkActions().exists()).toBe(false);
        });
      });

      describe('with replicable items', () => {
        beforeEach(() => {
          store.state.replicableItems = MOCK_BASIC_GRAPHQL_DATA;
        });

        it('does render bulk actions with correct actions', () => {
          expect(findGeoListBulkActions().props('bulkActions')).toStrictEqual(BULK_ACTIONS);
        });

        it('when bulk actions emits @bulkAction, initiateAllReplicableAction is called with correct action', async () => {
          findGeoListBulkActions().vm.$emit('bulkAction', BULK_ACTIONS[0].action);
          await nextTick();

          expect(store.dispatch).toHaveBeenCalledWith('initiateAllReplicableAction', {
            action: BULK_ACTIONS[0].action,
          });
        });
      });
    });
  });

  describe('banner', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the Geo Feedback Banner', () => {
      expect(findGeoFeedbackBanner().exists()).toBe(true);
    });
  });

  describe('onListboxChange', () => {
    beforeEach(() => {
      setWindowLocation(
        `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}?${MOCK_REPLICATION_STATUS_FILTER.type}=${MOCK_REPLICATION_STATUS_FILTER.value.data}`,
      );

      createStore();
      createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
    });

    it('preserves filters while updating the replicable type before calling processFilters and visitUrl', () => {
      const MOCK_NEW_REPLICABLE_TYPE = 'new_replicable_type';

      findGeoListFilteredSearchBar().vm.$emit('listboxChange', MOCK_NEW_REPLICABLE_TYPE);

      expect(processFilters).toHaveBeenCalledWith([
        { type: MOCK_REPLICABLE_TYPE_FILTER.type, value: MOCK_NEW_REPLICABLE_TYPE },
        { type: MOCK_REPLICATION_STATUS_FILTER.type, value: MOCK_REPLICATION_STATUS_FILTER.value },
      ]);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('onSearch', () => {
    beforeEach(() => {
      createStore();
      createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
    });

    it('processes filters and calls visitUrl', () => {
      findGeoListFilteredSearchBar().vm.$emit('search', MOCK_FILTERS);

      expect(processFilters).toHaveBeenCalledWith(MOCK_FILTERS);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
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
