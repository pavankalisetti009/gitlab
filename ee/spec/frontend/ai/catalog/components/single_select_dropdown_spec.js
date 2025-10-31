import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import {
  mockPageInfo,
  mockProjects,
  mockProjectsResponse,
  mockEmptyProjectsResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('SingleSelectDropdown', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'test-dropdown',
    query: getProjects,
    queryVariables: {
      sort: 'similarity',
    },
    dataKey: 'projects',
    placeholderText: 'Select an item',
    itemTextFn: (item) => item?.nameWithNamespace,
    itemLabelFn: (item) => item?.name,
    itemSubLabelFn: (item) => item?.nameWithNamespace,
  };

  const mockQueryHandler = jest.fn().mockResolvedValue(mockProjectsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([[getProjects, mockQueryHandler]]);

    wrapper = shallowMount(SingleSelectDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders listbox with correct props', () => {
      expect(findListbox().props()).toMatchObject({
        toggleId: 'test-dropdown',
        toggleText: 'Select an item',
        toggleClass: { 'gl-shadow-inner-1-red-500': false },
        headerText: 'Select an item',
        loading: true,
        searchable: true,
        block: true,
        fluidWidth: true,
        isCheckCentered: true,
        disabled: false,
      });
    });

    it('applies validation class when isValid is false', () => {
      createComponent({ props: { isValid: false } });

      expect(findListbox().props('toggleClass')).toEqual({
        'gl-shadow-inner-1-red-500': true,
      });
    });

    it('passes disabled prop to listbox', () => {
      createComponent({ props: { disabled: true } });

      expect(findListbox().props('disabled')).toBe(true);
    });
  });

  describe('Apollo query', () => {
    it('calls query with correct variables', () => {
      expect(mockQueryHandler).toHaveBeenCalledWith({
        search: '',
        after: '',
        first: PAGE_SIZE,
        sort: 'similarity',
        // default fields on the getProjects query
        membership: true,
        searchNamespaces: false,
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('updates items list when query resolves', () => {
        const expectedItems = mockProjects.map((item) => ({
          ...item,
          text: item.nameWithNamespace,
          value: String(item.id),
        }));

        expect(findListbox().props('items')).toEqual(expectedItems);
      });

      it('sets loading state to false after query completes', () => {
        expect(findListbox().props('loading')).toBe(false);
      });

      it('shows selected item text when value is provided', async () => {
        createComponent({ props: { value: mockProjects[0].id } });
        await waitForPromises();

        expect(findListbox().props('toggleText')).toBe(mockProjects[0].nameWithNamespace);
      });
    });

    describe('when request fails', () => {
      it('handles query error and emits error event', async () => {
        mockQueryHandler.mockRejectedValue(new Error('GraphQL error'));

        createComponent();
        await waitForPromises();

        expect(wrapper.emitted('error')).toHaveLength(1);
      });
    });

    describe('when response is empty', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValue(mockEmptyProjectsResponse);
        createComponent();
        await waitForPromises();
      });

      it('handles empty response', () => {
        expect(findListbox().props('items')).toEqual([]);
      });

      it('shows correct no results text', () => {
        expect(findListbox().props('noResultsText')).toBe('No results found');
      });
    });
  });

  describe('search functionality', () => {
    const searchAndWait = async (query) => {
      findListbox().vm.$emit('search', query);
      jest.advanceTimersByTime(250); // DEFAULT_DEBOUNCE_AND_THROTTLE_MS
      await waitForPromises();
    };

    beforeEach(async () => {
      await waitForPromises();
    });

    it('updates search query when searching', async () => {
      await searchAndWait('test query');

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test query',
        }),
      );
    });

    it('shows searching state during search', async () => {
      // Mock a pending query
      mockQueryHandler.mockReturnValue(new Promise(() => {}));

      await searchAndWait('test');

      expect(findListbox().props('searching')).toBe(true);
    });

    it('shows appropriate no results text for short queries', async () => {
      await searchAndWait('te');

      expect(findListbox().props('noResultsText')).toBe(
        'Enter at least three characters to search',
      );
    });

    it('shows default no results text for empty results', async () => {
      mockQueryHandler.mockResolvedValue(mockEmptyProjectsResponse);

      await searchAndWait('test query');

      expect(findListbox().props('noResultsText')).toBe('No results found');
    });
  });

  describe('infinite scrolling', () => {
    beforeEach(async () => {
      mockQueryHandler.mockClear();
      mockQueryHandler.mockResolvedValueOnce(mockProjectsResponse);
      mockQueryHandler.mockResolvedValueOnce(mockEmptyProjectsResponse);

      createComponent();
      await waitForPromises();
    });

    it('enables infinite scroll when there are more pages', () => {
      expect(findListbox().props('infiniteScroll')).toBe(true);
    });

    it('fetches next page when bottom is reached', async () => {
      findListbox().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(mockQueryHandler).toHaveBeenCalledTimes(2);
      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          after: mockPageInfo.endCursor,
        }),
      );
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      mockQueryHandler.mockResolvedValue(mockProjectsResponse);

      createComponent();
      await waitForPromises();
    });

    it('emits input event when item is selected', () => {
      findListbox().vm.$emit('select', mockProjects[1].id);

      expect(wrapper.emitted('input')).toEqual([[mockProjects[1]]]);
    });
  });
});
