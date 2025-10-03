import { GlAlert, GlEmptyState, GlFilteredSearch, GlSkeletonLoader } from '@gitlab/ui';
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
      expect(wrapper.emitted('updateCount')).toEqual([['2']]);
    });

    it('does not show empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not show loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
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
      expect(wrapper.emitted('updateCount')).toEqual([['0']]);
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
