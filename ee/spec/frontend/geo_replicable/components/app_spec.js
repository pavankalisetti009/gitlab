import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  ACTION_TYPES,
  BULK_ACTIONS,
  GEO_TROUBLESHOOTING_LINK,
  DEFAULT_PAGE_SIZE,
} from 'ee/geo_replicable/constants';
import GeoFeedbackBanner from 'ee/geo_replicable/components/geo_feedback_banner.vue';
import GeoReplicableApp from 'ee/geo_replicable/components/app.vue';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import replicableTypeBulkUpdateMutation from 'ee/geo_shared/graphql/replicable_type_bulk_update_mutation.graphql';
import buildReplicableTypeQuery from 'ee/geo_replicable/graphql/replicable_type_query_builder';
import { processFilters } from 'ee/geo_replicable/filters';
import { TEST_HOST } from 'spec/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import { setUrlParams, visitUrl } from '~/lib/utils/url_utility';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_CLASS,
  MOCK_REPLICABLE_TYPE_FILTER,
  MOCK_REPLICATION_STATUS_FILTER,
  MOCK_VERIFICATION_STATUS_FILTER,
  MOCK_GRAPHQL_PAGINATION_DATA,
} from '../mock_data';

const MOCK_FILTERS = { foo: 'bar' };
const MOCK_PROCESSED_FILTERS = { query: MOCK_FILTERS, url: { href: 'mock-url/params' } };
const MOCK_UPDATED_URL = 'mock-url/params?foo=bar';

const MOCK_BASE_LOCATION = `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}`;
const MOCK_REPLICATION_STATUS_QUERY = `${MOCK_REPLICATION_STATUS_FILTER.type}=${MOCK_REPLICATION_STATUS_FILTER.value.data}`;
const MOCK_VERIFICATION_STATUS_QUERY = `${MOCK_VERIFICATION_STATUS_FILTER.type}=${MOCK_VERIFICATION_STATUS_FILTER.value.data}`;

const MOCK_LOCATION_WITH_FILTERS = `${MOCK_BASE_LOCATION}?${MOCK_REPLICATION_STATUS_QUERY}&${MOCK_VERIFICATION_STATUS_QUERY}`;

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  setUrlParams: jest.fn(() => MOCK_UPDATED_URL),
  visitUrl: jest.fn(),
}));

jest.mock('ee/geo_replicable/filters', () => ({
  ...jest.requireActual('ee/geo_replicable/filters'),
  processFilters: jest.fn(() => MOCK_PROCESSED_FILTERS),
}));

jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');

Vue.use(VueApollo);

describe('GeoReplicableApp', () => {
  let wrapper;

  const defaultProvide = {
    itemTitle: 'Test Item',
    siteName: 'Test Site',
    replicableClass: MOCK_REPLICABLE_CLASS,
  };

  const MOCK_EMPTY_STATE = {
    title: `There are no ${defaultProvide.itemTitle} to show`,
    description:
      'No %{itemTitle} were found. If you believe this may be an error, please refer to the %{linkStart}Geo Troubleshooting%{linkEnd} documentation for more information.',
    itemTitle: defaultProvide.itemTitle,
    helpLink: GEO_TROUBLESHOOTING_LINK,
    hasFilters: false,
  };

  const query = buildReplicableTypeQuery(
    defaultProvide.replicableClass.graphqlFieldName,
    defaultProvide.replicableClass.verificationEnabled,
  );

  const MOCK_QUERY_HANDLER_WITH_DATA = jest.fn().mockResolvedValue({
    data: {
      geoNode: {
        [defaultProvide.replicableClass.graphqlFieldName]: {
          nodes: MOCK_BASIC_GRAPHQL_DATA,
          pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
        },
      },
    },
  });

  const MOCK_QUERY_HANDLER_WITHOUT_DATA = jest.fn().mockResolvedValue({
    data: {
      geoNode: {
        [defaultProvide.replicableClass.graphqlFieldName]: {
          nodes: [],
          pageInfo: {},
        },
      },
    },
  });

  const MOCK_SINGLE_MUTATION_HANDLER = jest.fn().mockResolvedValue({
    data: {
      geoRegistriesUpdate: {
        errors: [],
      },
    },
  });

  const MOCK_BULK_MUTATION_HANDLER = jest.fn().mockResolvedValue({
    data: {
      geoRegistriesBulkUpdate: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    provide,
    handler,
    singleMutationHandler,
    bulkMutationHandler,
  } = {}) => {
    const apolloQueryHandler = handler || MOCK_QUERY_HANDLER_WITH_DATA;
    const apolloSingleMutationHandler = singleMutationHandler || MOCK_SINGLE_MUTATION_HANDLER;
    const apolloBulkMutationHandler = bulkMutationHandler || MOCK_BULK_MUTATION_HANDLER;

    const apolloProvider = createMockApollo([
      [query, apolloQueryHandler],
      [replicableTypeUpdateMutation, apolloSingleMutationHandler],
      [replicableTypeBulkUpdateMutation, apolloBulkMutationHandler],
    ]);

    wrapper = shallowMount(GeoReplicableApp, {
      apolloProvider,
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findGeoReplicableContainer = () => wrapper.find('.geo-replicable-container');
  const findGeoReplicable = () => findGeoReplicableContainer().findComponent(GeoReplicable);
  const findGeoList = () => findGeoReplicableContainer().findComponent(GeoList);
  const findGeoListTopBar = () => findGeoReplicableContainer().findComponent(GeoListTopBar);
  const findGeoFeedbackBanner = () => wrapper.findComponent(GeoFeedbackBanner);

  beforeEach(() => {
    setWindowLocation(MOCK_BASE_LOCATION);
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('when isLoading is true renders GeoList with loading state true and GeoReplicable in default slot', () => {
      expect(findGeoList().props()).toStrictEqual({
        isLoading: true,
        hasItems: false,
        emptyState: MOCK_EMPTY_STATE,
      });

      expect(findGeoReplicable().exists()).toBe(true);
    });
  });

  describe.each`
    hasItems | handler
    ${true}  | ${MOCK_QUERY_HANDLER_WITH_DATA}
    ${false} | ${MOCK_QUERY_HANDLER_WITHOUT_DATA}
  `('GeoList state', ({ hasItems, handler }) => {
    describe(`${hasItems ? 'does' : 'does not'} have replicableItems`, () => {
      beforeEach(async () => {
        createComponent({ handler });

        await waitForPromises();
      });

      it('renders GeoList with the correct params', () => {
        expect(findGeoList().props()).toStrictEqual({
          isLoading: false,
          hasItems,
          emptyState: MOCK_EMPTY_STATE,
        });
      });

      it('renders GeoReplicable in the default slot of GeoList always', () => {
        expect(findGeoReplicable().exists()).toBe(true);
      });
    });
  });

  describe('error handling', () => {
    it('displays error message when Apollo query fails', async () => {
      const errorMessage = new Error('GraphQL Error');
      const handler = jest.fn().mockRejectedValue(errorMessage);
      createComponent({ handler });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message:
          'There was an error fetching the Test Item. The GraphQL API call to the secondary may have failed.',
        captureError: true,
        error: errorMessage,
      });
    });
  });

  describe.each`
    hasFilters | mockLocation
    ${false}   | ${MOCK_BASE_LOCATION}
    ${true}    | ${MOCK_LOCATION_WITH_FILTERS}
  `('empty state property', ({ hasFilters, mockLocation }) => {
    describe(`when filters are ${hasFilters}`, () => {
      beforeEach(async () => {
        setWindowLocation(mockLocation);

        createComponent({ handler: MOCK_QUERY_HANDLER_WITHOUT_DATA });

        await waitForPromises();
      });

      it('renders GeoList with correct empty state prop', () => {
        expect(findGeoList().props('emptyState')).toStrictEqual({
          ...MOCK_EMPTY_STATE,
          hasFilters,
        });
      });
    });
  });

  describe('filter bar', () => {
    describe('when no query is present', () => {
      beforeEach(() => {
        setWindowLocation(MOCK_BASE_LOCATION);

        createComponent();
      });

      it('renders top bar with correct listbox item and no search filters', () => {
        expect(findGeoListTopBar().props('activeListboxItem')).toBe(
          MOCK_REPLICABLE_TYPE_FILTER.value,
        );
        expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([]);
      });
    });

    describe('when query is present', () => {
      describe('when verification is enabled', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

          createComponent();
        });

        it('renders top bar with correct listbox item and search filters including verification status', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([
            MOCK_REPLICATION_STATUS_FILTER,
            MOCK_VERIFICATION_STATUS_FILTER,
          ]);
        });
      });

      describe('when verification is disabled', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

          createComponent({
            provide: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: false } },
          });
        });

        it('renders top bar with correct listbox item and search filters excluding verification status', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([
            MOCK_REPLICATION_STATUS_FILTER,
          ]);
        });
      });
    });
  });

  describe('bulk actions', () => {
    describe('with no replicable items', () => {
      beforeEach(async () => {
        createComponent({ handler: MOCK_QUERY_HANDLER_WITHOUT_DATA });

        await waitForPromises();
      });

      it('renders top bar with showActions=false', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });

    describe('with replicable items', () => {
      beforeEach(async () => {
        createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

        await waitForPromises();
      });

      it('renders top bar with showActions=true and correct actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(true);
        expect(findGeoListTopBar().props('bulkActions')).toStrictEqual(BULK_ACTIONS);
      });

      it('when top bar emits @bulkAction, bulk action mutation is called with correct action, emits a toast and calls refetch', async () => {
        findGeoListTopBar().vm.$emit('bulkAction', BULK_ACTIONS[0].action);
        await nextTick();

        expect(MOCK_BULK_MUTATION_HANDLER).toHaveBeenCalledWith({
          action: BULK_ACTIONS[0].action.toUpperCase(),
          registryClass: MOCK_REPLICABLE_CLASS.graphqlMutationRegistryClass,
        });

        await waitForPromises();

        expect(toast).toHaveBeenCalledWith('Scheduled all Test Item for resync.');
        expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledTimes(2);
      });
    });

    describe('when bulk action fails', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));
        createComponent({ bulkMutationHandler: errorMutationHandler });

        await waitForPromises();
      });

      it('when top bar emits @bulkAction, createAlert is called and not toast', async () => {
        findGeoListTopBar().vm.$emit('bulkAction', BULK_ACTIONS[0].action);
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error scheduling resync for all Test Item.',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
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

  describe('page title', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct title and description to the topbar', () => {
      expect(findGeoListTopBar().props('pageHeadingTitle')).toBe('Geo Replication - Test Site');
      expect(findGeoListTopBar().props('pageHeadingDescription')).toBe(
        'Review replication status, and resynchronize and reverify items with the primary site.',
      );
    });
  });

  describe('handleListboxChange', () => {
    beforeEach(() => {
      setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

      createComponent();
    });

    it('preserves filters while updating the replicable type before calling processFilters and visitUrl', () => {
      const MOCK_NEW_REPLICABLE_TYPE = 'new_replicable_type';

      findGeoListTopBar().vm.$emit('listboxChange', MOCK_NEW_REPLICABLE_TYPE);

      expect(processFilters).toHaveBeenCalledWith([
        { type: MOCK_REPLICABLE_TYPE_FILTER.type, value: MOCK_NEW_REPLICABLE_TYPE },
        { type: MOCK_REPLICATION_STATUS_FILTER.type, value: MOCK_REPLICATION_STATUS_FILTER.value },
        {
          type: MOCK_VERIFICATION_STATUS_FILTER.type,
          value: MOCK_VERIFICATION_STATUS_FILTER.value,
        },
      ]);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('handleSearch', () => {
    beforeEach(() => {
      createComponent();
    });

    it('processes filters and calls visitUrl', () => {
      findGeoListTopBar().vm.$emit('search', MOCK_FILTERS);

      expect(processFilters).toHaveBeenCalledWith(MOCK_FILTERS);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('handleNextPage', () => {
    beforeEach(async () => {
      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

      await waitForPromises();
    });

    it('calls Apollo query with updated cursor', async () => {
      findGeoReplicable().vm.$emit('next', 'test_item');
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          before: '',
          after: 'test_item',
          first: DEFAULT_PAGE_SIZE,
          last: null,
        }),
      );
    });
  });

  describe('handlePrevPage', () => {
    beforeEach(async () => {
      createComponent({ handler: MOCK_QUERY_HANDLER_WITH_DATA });

      await waitForPromises();
    });

    it('calls Apollo query with updated cursor', async () => {
      findGeoReplicable().vm.$emit('prev', 'test_item');
      await nextTick();

      expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledWith(
        expect.objectContaining({
          before: 'test_item',
          after: '',
          first: null,
          last: DEFAULT_PAGE_SIZE,
        }),
      );
    });
  });

  describe('handleSingleAction', () => {
    describe('when single action is successful', () => {
      beforeEach(async () => {
        createComponent();

        await waitForPromises();
      });

      it('properly calls the single action mutation, toast and refetch', async () => {
        findGeoReplicable().vm.$emit('actionClicked', {
          action: ACTION_TYPES.RESYNC,
          name: 'TestRegistry/1',
          registryId: '123',
        });
        await nextTick();

        expect(MOCK_SINGLE_MUTATION_HANDLER).toHaveBeenCalledWith({
          action: ACTION_TYPES.RESYNC.toUpperCase(),
          registryId: '123',
        });

        await waitForPromises();

        expect(toast).toHaveBeenCalledWith('Scheduled TestRegistry/1 for resync.');
        expect(MOCK_QUERY_HANDLER_WITH_DATA).toHaveBeenCalledTimes(2);
      });
    });

    describe('when single action is not successful', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));
        createComponent({ singleMutationHandler: errorMutationHandler });

        await waitForPromises();
      });

      it('calls createAlert and not toast', async () => {
        findGeoReplicable().vm.$emit('actionClicked', {
          action: ACTION_TYPES.RESYNC,
          name: 'TestRegistry/1',
          registryId: '123',
        });
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error scheduling TestRegistry/1 for resync.',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
      });
    });
  });
});
