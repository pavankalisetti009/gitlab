import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenUpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue';
import UpstreamsTable from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_table.vue';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import getMavenUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams.query.graphql';
import { groupMavenUpstreams } from '../../../mock_data';

Vue.use(VueApollo);

describe('MavenUpstreamsList', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org/gitlab',
  };

  const defaultProps = {
    pageParams: {
      first: 20,
    },
  };

  const mavenUpstreams = {
    data: {
      ...groupMavenUpstreams,
    },
  };

  const emptyMavenUpstreams = {
    data: {
      group: {
        ...groupMavenUpstreams.group,
        virtualRegistriesPackagesMavenUpstreams: {
          nodes: [],
          pageInfo: {},
        },
      },
    },
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUpstreamsTable = () => wrapper.findComponent(UpstreamsTable);
  const findEmptyResult = () => wrapper.findComponent(EmptyResult);

  const mavenUpstreamsHandler = jest.fn().mockResolvedValue(mavenUpstreams);
  const mockError = new Error('GraphQL error');
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({
    handlers = [[getMavenUpstreamsQuery, mavenUpstreamsHandler]],
    props = {},
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(MavenUpstreamsList, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  describe('initial state', () => {
    it('shows busy state while loading', () => {
      createComponent();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });

    it('fetches upstreams', () => {
      createComponent();

      expect(mavenUpstreamsHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org/gitlab',
        upstreamName: null,
        first: 20,
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
        value: [
          {
            type: 'filtered-search-term',
            value: { data: '' },
          },
        ],
      });
    });

    it('renders upstreams table with transformed data', () => {
      expect(findUpstreamsTable().props('upstreams')).toEqual(
        groupMavenUpstreams.group.virtualRegistriesPackagesMavenUpstreams.nodes.map((upstream) => ({
          ...upstream,
          id: getIdFromGraphQLId(upstream.id),
        })),
      );
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
          expect(mavenUpstreamsHandler).toHaveBeenCalledTimes(1);
          await findUpstreamsTable().vm.$emit('upstreamDeleted');

          expect(findAlert().props()).toMatchObject({
            variant: 'info',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('Maven upstream has been deleted.');
          expect(wrapper.emitted('upstream-deleted')).toHaveLength(1);
        });

        it('info alert can be dismissed', async () => {
          await findUpstreamsTable().vm.$emit('upstreamDeleted');

          await findAlert().vm.$emit('dismiss');

          expect(findAlert().exists()).toBe(false);
        });
      });

      describe('when `upstreamDeleteFailed` event is emitted', () => {
        it('shows error alert and does not refetch upstreams', async () => {
          expect(mavenUpstreamsHandler).toHaveBeenCalledTimes(1);
          await findUpstreamsTable().vm.$emit('upstreamDeleteFailed', 'error message');

          expect(findAlert().props()).toMatchObject({
            variant: 'danger',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('error message');
          expect(mavenUpstreamsHandler).toHaveBeenCalledTimes(1);
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
      createComponent({
        handlers: [[getMavenUpstreamsQuery, jest.fn().mockResolvedValue(emptyMavenUpstreams)]],
      });

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
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits submit event when filtered search is submitted', async () => {
      await findFilteredSearch().vm.$emit('submit', ['test-search']);

      expect(wrapper.emitted('submit')[0][0]).toBe('test-search');
    });

    it('emits submit event when filtered search is cleared', async () => {
      await findFilteredSearch().vm.$emit('clear');

      expect(wrapper.emitted('submit')[0][0]).toBe(null);
    });
  });

  describe('when searchTerm prop is set', () => {
    beforeEach(() => {
      createComponent({
        props: {
          searchTerm: 'test',
        },
      });
    });

    it('uses searchTerm for query', () => {
      expect(mavenUpstreamsHandler).toHaveBeenCalledWith({
        groupPath: 'gitlab-org/gitlab',
        upstreamName: 'test',
        first: 20,
      });
    });

    it('sets searchTerm for GlFilteredSeach', () => {
      expect(findFilteredSearch().props('value')).toStrictEqual([
        {
          type: 'filtered-search-term',
          value: { data: 'test' },
        },
      ]);
    });
  });

  describe('when searchTerm prop is set and there are no upstreams', () => {
    beforeEach(async () => {
      createComponent({
        props: {
          searchTerm: 'test',
        },
        handlers: [[getMavenUpstreamsQuery, jest.fn().mockResolvedValue(emptyMavenUpstreams)]],
      });
      await waitForPromises();
    });

    it('renders empty result component', () => {
      expect(findEmptyResult().exists()).toBe(true);
    });
  });

  describe('pagination', () => {
    describe('when pageParams prop is set with pagination values', () => {
      it('uses params for query', () => {
        createComponent({
          props: {
            pageParams: {
              after: '1232',
              first: 20,
            },
          },
        });
        expect(mavenUpstreamsHandler).toHaveBeenCalledWith({
          groupPath: 'gitlab-org/gitlab',
          upstreamName: null,
          first: 20,
          after: '1232',
        });
      });
    });

    it('configures pagination with correct props', async () => {
      createComponent();
      await waitForPromises();

      const { pageInfo } = groupMavenUpstreams.group.virtualRegistriesPackagesMavenUpstreams;
      const { __typename, ...rest } = pageInfo;

      expect(findPagination().props()).toMatchObject(rest);
    });

    it('sets table busy prop when paginating', async () => {
      createComponent();
      await waitForPromises();

      await wrapper.setProps({ pageParams: { after: '1234', first: 20 } });

      expect(findUpstreamsTable().props('busy')).toBe(true);
    });

    it('emits page-change event with correct parameters on pagination change', async () => {
      createComponent();
      await waitForPromises();

      await findPagination().vm.$emit('next');
      await findPagination().vm.$emit('prev');
      expect(wrapper.emitted('page-change')[0][0]).toEqual({ after: 'end' });
      expect(wrapper.emitted('page-change')[1][0]).toEqual({ before: 'start' });
    });
  });

  describe('error handling', () => {
    beforeEach(async () => {
      createComponent({
        handlers: [[getMavenUpstreamsQuery, errorHandler]],
      });
      await waitForPromises();
    });

    it('shows error alert when API call fails', () => {
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
      expect(findAlert().text()).toBe('GraphQL error');
    });
  });
});
