import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlKeysetPagination } from '@gitlab/ui';
import DependenciesTable from 'ee/dependencies/components/dependencies_table.vue';
import PaginatedDependenciesTable from 'ee/dependencies/components/paginated_dependencies_table.vue';
import createStore from 'ee/dependencies/store';
import TablePagination from '~/vue_shared/components/pagination/table_pagination.vue';
import * as urlUtility from '~/lib/utils/url_utility';
import { TEST_HOST } from 'helpers/test_constants';
import mockDependenciesResponse from '../store/mock_dependencies.json';

describe('PaginatedDependenciesTable component', () => {
  let store;
  let wrapper;
  let originalDispatch;

  const factory = (props = {}) => {
    store = createStore();

    wrapper = shallowMount(PaginatedDependenciesTable, {
      store,
      propsData: { ...props },
      provide: { vulnerabilitiesEndpoint: TEST_HOST },
    });
  };

  const findTablePagination = () => wrapper.findComponent(TablePagination);

  const expectComponentWithProps = (Component, props = {}) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.isVisible()).toBe(true);
    expect(componentWrapper.props()).toEqual(expect.objectContaining(props));
  };

  beforeEach(async () => {
    factory();

    originalDispatch = store.dispatch;
    jest.spyOn(store, 'dispatch').mockImplementation();
    jest.spyOn(urlUtility, 'updateHistory');

    await nextTick();
  });

  describe('when dependencies are received successfully via offset pagination', () => {
    beforeEach(async () => {
      originalDispatch('receiveDependenciesSuccess', {
        data: mockDependenciesResponse,
        headers: { 'X-Total': mockDependenciesResponse.dependencies.length },
      });

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: mockDependenciesResponse.dependencies,
        isLoading: store.state.isLoading,
        vulnerabilityItemsLoading: store.state.vulnerabilityItemsLoading,
        vulnerabilityInfo: store.state.vulnerabilityInfo,
      });
    });
  });

  it('passes the correct props to the pagination', () => {
    expectComponentWithProps(TablePagination, {
      change: wrapper.vm.fetchPage,
      pageInfo: store.state.pageInfo,
    });
  });

  it('has a fetchPage method which dispatches the correct action', () => {
    const page = 2;
    wrapper.vm.fetchPage(page);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith('fetchDependencies', { page });
  });

  it('fetchCursorPage dispatches the correct action', () => {
    const cursor = 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9';
    wrapper.vm.fetchCursorPage(cursor);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith('fetchDependencies', { cursor });
    expect(urlUtility.updateHistory).toHaveBeenCalledTimes(1);
    expect(urlUtility.updateHistory).toHaveBeenCalledWith({
      url: `${TEST_HOST}/?cursor=${cursor}`,
    });
  });

  it('dispatches fetch vulnerabilities', async () => {
    const item = {};
    const table = wrapper.findComponent(DependenciesTable);
    await table.vm.$emit('row-click', item);

    expect(store.dispatch).toHaveBeenCalledWith('fetchVulnerabilities', {
      item,
      vulnerabilitiesEndpoint: TEST_HOST,
    });
  });

  describe('when the list is loading', () => {
    let state;

    beforeEach(async () => {
      state = store.state;
      state.isLoading = true;
      state.errorLoading = false;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: state.dependencies,
        isLoading: true,
      });
    });

    it('does not render pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('does not render keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });
  });

  describe('when an error occured on load', () => {
    let state;

    beforeEach(async () => {
      state = store.state;
      state.isLoading = false;
      state.errorLoading = true;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: state.dependencies,
        isLoading: false,
      });
    });

    it('does not render pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('does not render keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });
  });

  describe('when the list is empty', () => {
    let state;

    beforeEach(async () => {
      state = store.state;
      state.dependencies = [];
      state.pageInfo.total = 0;

      state.isLoading = false;
      state.errorLoading = false;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: state.dependencies,
        isLoading: false,
      });
    });

    it('renders pagination', () => {
      expect(findTablePagination().exists()).toBe(true);
    });
  });

  describe('when dependencies are received successfully via cursor pagination', () => {
    beforeEach(async () => {
      originalDispatch('receiveDependenciesSuccess', {
        data: mockDependenciesResponse,
        headers: {
          'X-Page-Type': 'cursor',
          'X-Next-Page': 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9',
          'X-Prev-Page': '',
        },
      });

      await nextTick();
    });

    it('does not render offset pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('renders keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(true);
    });
  });
});
