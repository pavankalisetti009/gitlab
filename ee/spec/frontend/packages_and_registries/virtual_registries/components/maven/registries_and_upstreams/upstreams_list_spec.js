import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getMavenUpstreamRegistriesList } from 'ee/api/virtual_registries_api';
import MavenUpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue';
import UpstreamsTable from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_table.vue';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { mockUpstreams } from '../../../mock_data';

jest.mock('ee/api/virtual_registries_api', () => ({
  getMavenUpstreamRegistriesList: jest.fn(),
}));

describe('MavenUpstreamsList', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org/gitlab',
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPagination = () => wrapper.findComponent(GlPagination);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUpstreamsTable = () => wrapper.findComponent(UpstreamsTable);
  const findEmptyResult = () => wrapper.findComponent(EmptyResult);

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(MavenUpstreamsList, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    getMavenUpstreamRegistriesList.mockResolvedValue({
      data: mockUpstreams,
      headers: { 'x-total': '2' },
    });
  });

  describe('initial state', () => {
    it('shows skeleton loader while loading', () => {
      createComponent();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });

    it('fetches upstreams on mount', () => {
      createComponent();

      expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
        id: 'gitlab-org/gitlab',
        params: {
          upstream_name: '',
          page: 1,
          per_page: 20,
        },
      });
    });
  });

  describe('with upstreams data', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders filtered search', () => {
      expect(findFilteredSearch().props()).toMatchObject({
        placeholder: 'Filter results',
        searchTextOptionLabel: 'Search for this text',
        termsAsTokens: true,
      });
    });

    it('renders upstreams table with transformed data', () => {
      expect(findUpstreamsTable().props('upstreams')).toEqual([
        {
          id: 1,
          name: 'Maven Central',
          url: 'https://repo1.maven.org/maven2/',
          cacheValidityHours: 24,
          metadataCacheValidityHours: 12,
        },
        {
          id: 2,
          name: 'JCenter',
          url: 'https://jcenter.bintray.com/',
          cacheValidityHours: 48,
          metadataCacheValidityHours: 24,
        },
      ]);
    });

    it('emits updateCount event with total count', () => {
      expect(wrapper.emitted('updateCount')).toEqual([[2]]);
    });

    it('does not show empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not show loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    describe('upstreams table events', () => {
      describe('when `upstreamDeleted` event is emitted', () => {
        it('shows info alert and refetches upstreams', async () => {
          expect(getMavenUpstreamRegistriesList).toHaveBeenCalledTimes(1);
          await findUpstreamsTable().vm.$emit('upstreamDeleted');

          expect(findAlert().props()).toMatchObject({
            variant: 'info',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('Maven upstream has been deleted.');

          expect(getMavenUpstreamRegistriesList).toHaveBeenCalledTimes(2);
          expect(getMavenUpstreamRegistriesList).toHaveBeenLastCalledWith({
            id: 'gitlab-org/gitlab',
            params: {
              upstream_name: '',
              page: 1,
              per_page: 20,
            },
          });
        });

        it('info alert can be dismissed', async () => {
          await findUpstreamsTable().vm.$emit('upstreamDeleted');

          await findAlert().vm.$emit('dismiss');

          expect(findAlert().exists()).toBe(false);
        });
      });

      describe('when `upstreamDeleteFailed` event is emitted', () => {
        it('shows error alert and does not refetch upstreams', async () => {
          expect(getMavenUpstreamRegistriesList).toHaveBeenCalledTimes(1);
          await findUpstreamsTable().vm.$emit('upstreamDeleteFailed', 'error message');

          expect(findAlert().props()).toMatchObject({
            variant: 'danger',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('error message');
          expect(getMavenUpstreamRegistriesList).toHaveBeenCalledTimes(1);
        });

        it('error alert can be dismissed', async () => {
          await findUpstreamsTable().vm.$emit('upstreamDeleteFailed', 'error message');

          await findAlert().vm.$emit('dismiss');

          expect(findAlert().exists()).toBe(false);
        });
      });
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      getMavenUpstreamRegistriesList.mockResolvedValue({
        data: [],
        headers: { 'x-total': '0' },
      });
      createComponent();
      await waitForPromises();
    });

    it('renders empty state when no upstreams exist', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props()).toMatchObject({
        title: 'Connect Maven virtual registry to an upstream',
        description: 'Configure an upstream registry to manage Maven artifacts and cache entries.',
      });
    });

    it('does not render filtered search or table', () => {
      expect(findFilteredSearch().exists()).toBe(false);
      expect(findUpstreamsTable().exists()).toBe(false);
    });

    it('emits updateCount event with zero', () => {
      expect(wrapper.emitted('updateCount')).toEqual([[0]]);
    });
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('performs search when filtered search is submitted', async () => {
      getMavenUpstreamRegistriesList.mockClear();

      findFilteredSearch().vm.$emit('submit', ['test-search']);
      await waitForPromises();

      expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
        id: 'gitlab-org/gitlab',
        params: {
          upstream_name: 'test-search',
          page: 1,
          per_page: 20,
        },
      });
    });

    it('shows empty result when search returns no results', async () => {
      getMavenUpstreamRegistriesList.mockResolvedValue({
        data: [],
        headers: { 'x-total': '0' },
      });

      findFilteredSearch().vm.$emit('submit', ['no-results']);
      await waitForPromises();

      expect(findEmptyResult().exists()).toBe(true);
      expect(findUpstreamsTable().exists()).toBe(false);
    });

    it('shows busy state while searching', async () => {
      findFilteredSearch().vm.$emit('submit', ['searching']);
      await nextTick();

      expect(findUpstreamsTable().props('busy')).toBe(true);
    });
  });

  describe('pagination', () => {
    describe('when total count is greater than page size', () => {
      beforeEach(async () => {
        getMavenUpstreamRegistriesList.mockResolvedValue({
          data: mockUpstreams,
          headers: { 'x-total': '25' },
        });
        createComponent();
        await waitForPromises();
      });

      it('shows pagination component', () => {
        expect(findPagination().exists()).toBe(true);
      });

      it('configures pagination with correct props', () => {
        expect(findPagination().props()).toMatchObject({
          value: 1,
          perPage: 20,
          totalItems: 25,
        });
      });

      it('fetches data for new page when pagination changes', async () => {
        getMavenUpstreamRegistriesList.mockClear();

        findPagination().vm.$emit('input', 2);
        await waitForPromises();

        expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
          id: 'gitlab-org/gitlab',
          params: {
            upstream_name: '',
            page: 2,
            per_page: 20,
          },
        });
      });

      it('maintains search term when changing pages', async () => {
        findFilteredSearch().vm.$emit('submit', ['test-search']);
        await waitForPromises();
        getMavenUpstreamRegistriesList.mockClear();

        findPagination().vm.$emit('input', 3);
        await waitForPromises();

        expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
          id: 'gitlab-org/gitlab',
          params: {
            upstream_name: 'test-search',
            page: 3,
            per_page: 20,
          },
        });
      });

      it('resets page to 1 when search term changes', () => {
        findPagination().vm.$emit('input', 2);
        findFilteredSearch().vm.$emit('submit', ['test-search']);

        expect(getMavenUpstreamRegistriesList).toHaveBeenLastCalledWith({
          id: 'gitlab-org/gitlab',
          params: {
            upstream_name: 'test-search',
            page: 1,
            per_page: 20,
          },
        });
      });
    });

    describe('when total count is less than or equal to page size', () => {
      beforeEach(async () => {
        getMavenUpstreamRegistriesList.mockResolvedValue({
          data: mockUpstreams,
          headers: { 'x-total': '15' },
        });
        createComponent();
        await waitForPromises();
      });

      it('does not show pagination component', () => {
        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('error handling', () => {
    const errorMessage = 'Network error occurred';

    beforeEach(async () => {
      getMavenUpstreamRegistriesList.mockRejectedValue(new Error(errorMessage));
      createComponent();
      await waitForPromises();
    });

    it('shows error alert when API call fails', () => {
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
      expect(findAlert().text()).toBe(errorMessage);
    });
  });
});
