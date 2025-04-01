import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlAlert, GlLoadingIcon, GlKeysetPagination } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';
import StandardsAdherenceTableV2 from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table_v2.vue';
import DetailsDrawer from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/details_drawer.vue';
import GroupedTable from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_table.vue';
import { GroupedLoader } from 'ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader';
import { GRAPHQL_FIELD_MISSING_ERROR_MESSAGE } from 'ee/compliance_dashboard/constants';
import { isGraphqlFieldMissingError } from 'ee/compliance_dashboard/utils';

jest.mock('ee/compliance_dashboard/components/standards_adherence_report/services/grouped_loader');
jest.mock('ee/compliance_dashboard/utils');

describe('StandardsAdherenceTableV2', () => {
  let wrapper;

  const findGroupedTable = () => wrapper.findComponent(GroupedTable);
  const findDetailsDrawer = () => wrapper.findComponent(DetailsDrawer);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const waitForNextPageLoad = async () => {
    // triggers loading state
    await nextTick();
    // wait for resolve
    await waitForPromises();
    // render
    await nextTick();
    // extra tick for Vue.js 3
    await nextTick();
  };

  const groupPath = 'group/path';
  const mockItems = {
    data: [
      {
        group: null,
        children: {
          category1: [{ id: '1', name: 'Requirement 1' }],
          category2: [{ id: '2', name: 'Requirement 2' }],
        },
      },
    ],
    pageInfo: { hasNextPage: false },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(StandardsAdherenceTableV2, {
      propsData: {
        groupPath,
        ...props,
      },
      mocks: {
        $apollo: {},
      },
    });
  };

  beforeEach(() => {
    GroupedLoader.mockClear();
    // Mock the GroupedLoader implementation
    GroupedLoader.mockImplementation(function mockGroupedLoader() {
      this.loadPage = jest.fn().mockResolvedValue(mockItems);
    });
  });

  describe('initialization', () => {
    it('renders loading state', () => {
      createComponent();
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findGroupedTable().exists()).toBe(false);
    });

    it('initializes GroupedLoader with correct parameters', () => {
      createComponent();

      expect(GroupedLoader).toHaveBeenCalledWith({
        fullPath: groupPath,
        apollo: expect.any(Object),
      });
      expect(GroupedLoader.mock.instances.at(-1).loadPage).toHaveBeenCalled();
    });
  });

  describe('after data is loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays GroupedTable', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findGroupedTable().exists()).toBe(true);
    });

    it('passes items data to GroupedTable', () => {
      expect(findGroupedTable().props('items')).toEqual(mockItems.data);
    });

    describe('row selection', () => {
      const selectedItem = { id: '1', name: 'Selected Item' };

      it('updates selectedStatus when a row is selected', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);
      });

      it('passes selected status to details drawer', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();
        await nextTick();
        expect(findDetailsDrawer().props('status')).toEqual(selectedItem);
      });

      it('clears selected status when DetailsDrawer emits close', async () => {
        findGroupedTable().vm.$emit('row-selected', selectedItem);
        await nextTick();

        findDetailsDrawer().vm.$emit('close');
        await nextTick();

        expect(findDetailsDrawer().props('status')).toBe(null);
      });
    });
  });

  describe('error handling', () => {
    it('sets generic error message when fetch fails', async () => {
      GroupedLoader.mockImplementation(() => ({
        loadPage: jest.fn().mockRejectedValue(new Error('Network error')),
      }));

      createComponent();

      // one tick to trigger load (double for Vue.js 3)
      await nextTick();
      await nextTick();
      // and another to display failure
      await nextTick();
      await nextTick();

      expect(findAlert().text()).toContain('There was an error');

      await nextTick();
    });

    it('sets specific error message for GraphQL field missing error', async () => {
      const error = new Error('GraphQL error');
      isGraphqlFieldMissingError.mockReturnValue(true);

      GroupedLoader.mockImplementation(() => ({
        loadPage: jest.fn().mockRejectedValue(error),
      }));

      createComponent();

      // one tick to trigger load (double for Vue.js 3)
      await nextTick();
      await nextTick();
      // and another to display failure
      await nextTick();
      await nextTick();

      expect(isGraphqlFieldMissingError).toHaveBeenCalledWith(
        error,
        'projectComplianceRequirementsStatus',
      );
      expect(findAlert().text()).toContain(GRAPHQL_FIELD_MISSING_ERROR_MESSAGE);
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      GroupedLoader.mockImplementation(function mockGroupedLoader() {
        this.loadPage = jest.fn().mockResolvedValue(mockItems);
        this.loadNextPage = jest.fn().mockResolvedValue({
          data: [{ group: null, children: { category3: [{ id: '3', name: 'Requirement 3' }] } }],
          pageInfo: { hasNextPage: false, hasPreviousPage: true },
        });
        this.loadPrevPage = jest.fn().mockResolvedValue(mockItems);
        this.setPageSize = jest.fn();
      });

      createComponent();
      return nextTick();
    });

    const findPagination = () => wrapper.findComponent(GlKeysetPagination);
    const findPageSizeSelector = () => wrapper.findComponent(PageSizeSelector);

    it('displays pagination component when pageInfo is available', () => {
      expect(findPagination().exists()).toBe(true);
    });

    it('loads next page when next is clicked', async () => {
      findPagination().vm.$emit('next');

      expect(GroupedLoader.mock.instances[0].loadNextPage).toHaveBeenCalled();

      await waitForNextPageLoad();

      expect(findGroupedTable().props('items')).toEqual([
        { group: null, children: { category3: [{ id: '3', name: 'Requirement 3' }] } },
      ]);
    });

    it('loads previous page when prev is clicked', async () => {
      findPagination().vm.$emit('prev');

      expect(GroupedLoader.mock.instances[0].loadPrevPage).toHaveBeenCalled();

      await waitForNextPageLoad();

      expect(findGroupedTable().props('items')).toEqual(mockItems.data);
    });

    it('updates page size and reloads data when page size changes', async () => {
      const newPageSize = 50;
      findPageSizeSelector().vm.$emit('input', newPageSize);

      expect(GroupedLoader.mock.instances[0].setPageSize).toHaveBeenCalledWith(newPageSize);
      expect(GroupedLoader.mock.instances[0].loadPage).toHaveBeenCalled();

      await waitForNextPageLoad();
      expect(wrapper.findComponent(PageSizeSelector).props('value')).toBe(newPageSize);
    });
  });
});
