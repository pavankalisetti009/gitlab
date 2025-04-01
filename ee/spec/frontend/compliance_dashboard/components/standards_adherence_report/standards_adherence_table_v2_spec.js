import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
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
        apollo: wrapper.vm.$apollo,
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
});
