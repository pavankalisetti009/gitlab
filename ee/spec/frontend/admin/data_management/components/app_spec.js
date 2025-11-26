import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueRouter from 'vue-router';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { MOCK_MODEL_TYPES } from 'ee_jest/admin/data_management/mock_data';
import showToast from '~/vue_shared/plugins/global_toast';
import { BULK_ACTIONS } from 'ee/admin/data_management/constants';
import { getModels, putBulkModelAction } from 'ee/api/data_management_api';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createRouter } from 'ee/admin/data_management/router';

Vue.use(VueRouter);

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');
jest.mock('~/vue_shared/plugins/global_toast');

describe('AdminDataManagementApp', () => {
  let wrapper;
  let router;

  const [defaultModel, otherModel] = MOCK_MODEL_TYPES;
  const defaultModelTitle = defaultModel.titlePlural.toLowerCase();
  const defaultBasePath = 'admin/data_management';

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementApp, {
      router,
      propsData: {
        modelTypes: MOCK_MODEL_TYPES,
        initialModelName: defaultModel.name,
      },
    });
  };

  const findGeoListTopBar = () => wrapper.findComponent(GeoListTopBar);
  const findGeoList = () => wrapper.findComponent(GeoList);
  const findDataManagementItem = () => wrapper.findComponent(DataManagementItem);

  const fireBulkAction = (action) => findGeoListTopBar().vm.$emit('bulkAction', action);

  beforeEach(() => {
    router = createRouter(defaultBasePath);
  });

  it('renders GeoListTopBar', () => {
    createComponent();

    expect(findGeoListTopBar().props()).toMatchObject({
      pageHeadingTitle: 'Data management',
      pageHeadingDescription: 'Review stored data and data health within your instance.',
      filteredSearchOptionLabel: 'Search by ID',
      activeListboxItem: defaultModel.name,
      activeSort: { value: 'id', direction: 'asc' },
      bulkActions: BULK_ACTIONS,
      showActions: false,
    });
  });

  it('renders GeoList', () => {
    createComponent();

    expect(findGeoList().props()).toMatchObject({
      isLoading: true,
      hasItems: false,
      emptyState: {
        title: `No ${defaultModelTitle} exist`,
        description:
          'If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        helpLink: '/help/administration/geo/replication/troubleshooting/_index.md',
        hasFilters: false,
      },
    });
  });

  describe('API calls', () => {
    it('calls getModels with correct parameters', () => {
      createComponent();

      expect(getModels).toHaveBeenCalledWith(defaultModel.name, {});
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
        expect(findDataManagementItem().props()).toMatchObject({
          initialItem: item,
          modelName: defaultModel.name,
        });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('shows bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(true);
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

      it('does not show bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
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
        const message = `There was an error fetching ${defaultModelTitle}. Please refresh the page and try again.`;
        expect(createAlert).toHaveBeenCalledWith({ message, captureError: true, error });
      });

      it('stops loading state', () => {
        expect(findGeoList().props('isLoading')).toBe(false);
      });

      it('does not show bulk actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });
  });

  describe('when URL has params', () => {
    beforeEach(async () => {
      await router.push({
        name: 'root',
        params: { modelName: otherModel.name },
        query: {
          identifiers: ['123', '456'],
          checksum_state: 'failed',
        },
      });

      createComponent();
    });

    it('updates route modelName', () => {
      expect(router.currentRoute.params.modelName).toBe(otherModel.name);
    });

    it('updates route query', () => {
      expect(router.currentRoute.query).toStrictEqual({
        checksum_state: 'failed',
        identifiers: ['123', '456'],
      });
    });

    it('calls getModels with correct parameters', () => {
      expect(getModels).toHaveBeenCalledWith(otherModel.name, {
        identifiers: ['123', '456'],
        checksum_state: 'failed',
      });
    });

    it('passes initial filter to GeoListTopBar', () => {
      expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toMatchObject([
        '123 456',
        { type: 'checksum_state', value: { data: 'failed' } },
      ]);
    });

    it('sets emptyState hasFilter field to true', () => {
      expect(findGeoList().props()).toMatchObject({
        emptyState: { hasFilters: true },
      });
    });
  });

  describe('when GeoListTopBar emits `listboxChange` event', () => {
    beforeEach(async () => {
      createComponent();

      findGeoListTopBar().vm.$emit('listboxChange', otherModel.name);
      await waitForPromises();
    });

    it('updates route modelName', () => {
      expect(router.currentRoute.params.modelName).toBe(otherModel.name);
    });

    it('calls getModels with correct params', () => {
      expect(getModels).toHaveBeenCalledWith(otherModel.name, {});
    });
  });

  describe('when GeoListTopBar emits `search` event', () => {
    beforeEach(async () => {
      createComponent();

      findGeoListTopBar().vm.$emit('search', [
        '123 456',
        { type: 'checksum_state', value: { data: 'failed' } },
      ]);

      await waitForPromises();
    });

    it('updates route query', () => {
      expect(router.currentRoute.query).toStrictEqual({
        checksum_state: 'failed',
        identifiers: ['123', '456'],
      });
    });

    it('calls getModels with correct params', () => {
      expect(getModels).toHaveBeenCalledWith(defaultModel.name, {
        identifiers: ['123', '456'],
        checksum_state: 'failed',
      });
    });
  });

  describe('when GeoListTopBar emits `buildAction` event', () => {
    const [action] = BULK_ACTIONS;

    beforeEach(async () => {
      getModels.mockResolvedValue({ data: [] });
      createComponent();

      await waitForPromises();
      getModels.mockClear();
    });

    it('calls putBulkModelAction', () => {
      fireBulkAction(action);

      expect(putBulkModelAction).toHaveBeenCalledWith(defaultModel.name, action.action);
    });

    describe('when action succeeds', () => {
      beforeEach(async () => {
        putBulkModelAction.mockResolvedValue({ data: defaultModel });
        fireBulkAction(action);
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(showToast).toHaveBeenCalledWith(
          `Scheduled all ${defaultModelTitle} for checksum recalculation.`,
        );
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('reloads models', () => {
        expect(getModels).toHaveBeenCalled();
      });
    });

    describe('when action fails', () => {
      const error = new Error('failed to run bulk action');

      beforeEach(async () => {
        putBulkModelAction.mockRejectedValue(error);
        fireBulkAction(action);
        await waitForPromises();
      });

      it('does not show toast', () => {
        expect(showToast).not.toHaveBeenCalled();
      });

      it('creates alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: `There was an error scheduling all ${defaultModelTitle} for checksum recalculation.`,
          captureError: true,
          error,
        });
      });

      it('does not reload models', () => {
        expect(getModels).not.toHaveBeenCalled();
      });
    });
  });
});
