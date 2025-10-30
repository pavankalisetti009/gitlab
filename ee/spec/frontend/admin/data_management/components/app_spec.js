import { shallowMount } from '@vue/test-utils';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { MOCK_MODEL_CLASS } from 'ee_jest/admin/data_management/mock_data';
import {
  TOKEN_TYPES,
  DEFAULT_SORT,
  GEO_TROUBLESHOOTING_LINK,
} from 'ee/admin/data_management/constants';
import { updateHistory, visitUrl } from '~/lib/utils/url_utility';
import { TEST_HOST } from 'spec/test_constants';
import { getModels } from 'ee/api/data_management_api';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import setWindowLocation from 'helpers/set_window_location_helper';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
  updateHistory: jest.fn(),
}));
jest.mock('~/alert');
jest.mock('ee/api/data_management_api');

describe('AdminDataManagementApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementApp, {
      propsData: {
        modelClass: MOCK_MODEL_CLASS,
      },
    });
  };

  const findGeoListTopBar = () => wrapper.findComponent(GeoListTopBar);
  const findGeoList = () => wrapper.findComponent(GeoList);
  const findDataManagementItem = () => wrapper.findComponent(DataManagementItem);

  beforeEach(() => {
    createComponent();
  });

  it('renders GeoListTopBar', () => {
    createComponent();

    expect(findGeoListTopBar().props()).toMatchObject({
      pageHeadingTitle: 'Data management',
      pageHeadingDescription: 'Review stored data and data health within your instance.',
      filteredSearchOptionLabel: 'Search by ID',
      activeListboxItem: MOCK_MODEL_CLASS.name,
      activeSort: DEFAULT_SORT,
    });
  });

  it('renders GeoList', () => {
    createComponent();

    expect(findGeoList().props()).toMatchObject({
      isLoading: true,
      hasItems: false,
      emptyState: {
        title: `No ${MOCK_MODEL_CLASS.titlePlural.toLowerCase()} exist`,
        description:
          'If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: false,
      },
    });
  });

  describe('API calls', () => {
    it('calls getModels with correct parameters', () => {
      createComponent();

      expect(getModels).toHaveBeenCalledWith(MOCK_MODEL_CLASS.name, {});
    });

    describe('while loading model is querying', () => {
      it('shows loading state', () => {
        createComponent();

        expect(findGeoList().props('isLoading')).toBe(true);
      });
    });

    describe('when loading models succeeds', () => {
      beforeEach(async () => {
        getModels.mockResolvedValue({ data: models });
        createComponent();
        await waitForPromises();
      });

      it('renders items on GeoList', () => {
        const [item] = convertObjectPropsToCamelCase(models, { deep: true });

        expect(findGeoList().props('hasItems')).toBe(true);
        expect(findDataManagementItem().props()).toMatchObject({ item });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when loading models returns empty array', () => {
      beforeEach(async () => {
        getModels.mockResolvedValue({ data: [] });
        createComponent();
        await waitForPromises();
      });

      it('shows empty state', () => {
        expect(findGeoList().props('hasItems')).toBe(false);
        expect(findGeoList().findAll('li')).toHaveLength(0);
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when loading models fails', () => {
      const error = new Error('Failed to load models');

      beforeEach(async () => {
        getModels.mockRejectedValue(error);
        createComponent();
        await waitForPromises();
      });

      it('creates alert', () => {
        const message = `There was an error fetching ${MOCK_MODEL_CLASS.titlePlural.toLowerCase()}. Please refresh the page and try again.`;
        expect(createAlert).toHaveBeenCalledWith({ message, captureError: true, error });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
      });
    });
  });

  describe('when URL has params', () => {
    beforeEach(() => {
      const params = new URLSearchParams([
        [`${TOKEN_TYPES.IDENTIFIERS}[]`, '123'],
        [`${TOKEN_TYPES.IDENTIFIERS}[]`, '456'],
        [TOKEN_TYPES.CHECKSUM_STATE, 'failed'],
      ]);

      setWindowLocation(`?${params.toString()}`);

      createComponent();
    });

    it('calls getModels with correct parameters', () => {
      expect(getModels).toHaveBeenCalledWith(MOCK_MODEL_CLASS.name, {
        [TOKEN_TYPES.IDENTIFIERS]: ['123', '456'],
        [TOKEN_TYPES.CHECKSUM_STATE]: 'failed',
      });
    });

    it('passes initial filter to GeoListTopBar', () => {
      expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toMatchObject([
        '123 456',
        { type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: 'failed' } },
      ]);
    });

    it('sets emptyState hasFilter field to true', () => {
      expect(findGeoList().props()).toMatchObject({
        emptyState: { hasFilters: true },
      });
    });
  });

  describe('when GeoListTopBar emits `listboxChange` event', () => {
    it('redirects to page with correct params', () => {
      createComponent();

      findGeoListTopBar().vm.$emit('listboxChange', 'foo');

      expect(visitUrl).toHaveBeenCalledWith(`${TEST_HOST}/?model_name=foo`);
    });
  });

  describe('when GeoListTopBar emits `search` event', () => {
    beforeEach(() => {
      createComponent();

      findGeoListTopBar().vm.$emit('search', [
        '123 456',
        { type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: 'failed' } },
      ]);
    });

    it('calls updateHistory with correct params', () => {
      const params = new URLSearchParams([
        [TOKEN_TYPES.MODEL, MOCK_MODEL_CLASS.name],
        [`${TOKEN_TYPES.IDENTIFIERS}[]`, '123'],
        [`${TOKEN_TYPES.IDENTIFIERS}[]`, '456'],
        [TOKEN_TYPES.CHECKSUM_STATE, 'failed'],
      ]);

      expect(updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?${params.toString()}`,
      });
    });

    it('calls getModels with correct params', () => {
      expect(getModels).toHaveBeenCalledWith(MOCK_MODEL_CLASS.name, {
        [TOKEN_TYPES.IDENTIFIERS]: ['123', '456'],
        [TOKEN_TYPES.CHECKSUM_STATE]: 'failed',
      });
    });

    it('shows loading state', () => {
      createComponent();

      expect(findGeoList().props('isLoading')).toBe(true);
    });
  });
});
