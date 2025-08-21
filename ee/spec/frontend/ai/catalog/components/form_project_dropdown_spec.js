import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import {
  mockPageInfo,
  mockProjects,
  mockProjectsResponse,
  mockEmptyProjectsResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('FormProjectDropdown', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'gl-form-field-project',
  };
  const mockProjectsQueryHandler = jest.fn().mockResolvedValue(mockProjectsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([[getProjects, mockProjectsQueryHandler]]);

    wrapper = shallowMount(FormProjectDropdown, {
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

  it('renders listbox as loading', () => {
    expect(findListbox().props('toggleId')).toBe(defaultProps.id);
    expect(findListbox().props('loading')).toBe(true);
  });

  it('shows default toggle text when no project is selected', async () => {
    await waitForPromises();

    expect(findListbox().props('toggleText')).toBe('Select a project');
  });

  it('shows selected project name when project is selected', async () => {
    createComponent({ props: { value: 'gid://gitlab/Project/1' } });
    await waitForPromises();

    expect(findListbox().props('toggleText')).toBe('Group / Project 1');
  });

  describe('Apollo query', () => {
    it('calls getProjects query with correct variables', () => {
      expect(mockProjectsQueryHandler).toHaveBeenCalledWith({
        after: '',
        first: 20,
        membership: true,
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        searchNamespaces: false,
        search: '',
        sort: 'similarity',
      });
    });

    describe('when request succeeds', () => {
      it('updates projects list when query resolves', async () => {
        await waitForPromises();

        const expectedItems = mockProjects.map((project) => ({
          ...project,
          text: project.nameWithNamespace,
          value: String(project.id),
        }));

        expect(findListbox().props('items')).toEqual(expectedItems);
      });

      it('handles empty projects response', async () => {
        mockProjectsQueryHandler.mockResolvedValue(mockEmptyProjectsResponse);

        createComponent();
        await waitForPromises();

        expect(findListbox().props('items')).toEqual([]);
      });

      it('sets loading state to false after query completes', async () => {
        expect(findListbox().props('loading')).toBe(true);

        await waitForPromises();

        expect(findListbox().props('loading')).toBe(false);
      });
    });

    describe('when request fails', () => {
      it('handles query error and emits error event', async () => {
        mockProjectsQueryHandler.mockRejectedValue(new Error('GraphQL error'));

        createComponent();
        await waitForPromises();

        expect(wrapper.emitted('error')).toEqual([['Failed to load projects']]);
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
      createComponent();
      await waitForPromises();
    });

    it('updates search query when searching', async () => {
      await searchAndWait('test query');

      expect(mockProjectsQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test query',
        }),
      );
    });

    it('shows searching state during search', async () => {
      // Mock a pending query
      mockProjectsQueryHandler.mockReturnValue(new Promise(() => {}));

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
      mockProjectsQueryHandler.mockResolvedValue(mockEmptyProjectsResponse);

      await searchAndWait('test query');

      expect(findListbox().props('noResultsText')).toBe('No results found');
    });
  });

  describe('infinite scrolling', () => {
    beforeEach(async () => {
      mockProjectsQueryHandler.mockClear();
      mockProjectsQueryHandler.mockResolvedValueOnce(mockProjectsResponse);
      mockProjectsQueryHandler.mockResolvedValueOnce(mockEmptyProjectsResponse);

      createComponent();
      await waitForPromises();
    });
    it('enables infinite scroll when there are more pages', () => {
      expect(findListbox().props('infiniteScroll')).toBe(true);
    });

    it('fetches next page when bottom is reached', async () => {
      await waitForPromises();

      findListbox().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(mockProjectsQueryHandler).toHaveBeenCalledTimes(2);
      expect(mockProjectsQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          after: mockPageInfo.endCursor,
        }),
      );
    });
  });

  describe('project selection', () => {
    it('emits input event when project is selected', () => {
      findListbox().vm.$emit('select', 'gid://gitlab/Project/1');

      expect(wrapper.emitted('input')).toEqual([['gid://gitlab/Project/1']]);
    });
  });
});
