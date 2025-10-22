import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlEmptyState, GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import getMavenVirtualRegistriesQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registries.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistriesList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_list.vue';
import RegistriesTable from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_table.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import { TEST_HOST } from 'spec/test_constants';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { groupVirtualRegistries } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

const PAGE_SIZE = 20;

describe('MavenRegistriesList', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org',
  };

  const mockMavenRegistries = {
    data: {
      ...groupVirtualRegistries,
    },
  };

  const mockEmptyMavenRegistries = {
    data: {
      group: {
        ...groupVirtualRegistries.group,
        mavenVirtualRegistries: { nodes: [], pageInfo: {} },
      },
    },
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRegistriesTable = () => wrapper.findComponent(RegistriesTable);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const mavenRegistriesHandler = jest.fn().mockResolvedValue(mockMavenRegistries);
  const emptyMavenRegistriesHandler = jest.fn().mockResolvedValue(mockEmptyMavenRegistries);
  const mockError = new Error('GraphQL error');
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({ handlers = [] } = {}) => {
    wrapper = shallowMountExtended(MavenRegistriesList, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        ...defaultProvide,
      },
    });
  };

  describe('component initialization', () => {
    beforeEach(() => {
      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, mavenRegistriesHandler]] });
    });

    it('calls the GraphQL query with right parameters', () => {
      expect(mavenRegistriesHandler).toHaveBeenCalledWith({
        groupPath: defaultProvide.fullPath,
        first: PAGE_SIZE,
      });
    });

    it('displays the skeleton loader during loading', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findAlert().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistriesTable().exists()).toBe(false);
    });

    describe('when the API returns data', () => {
      it('displays the registry items with the correct props', async () => {
        await waitForPromises();

        expect(findSkeletonLoader().exists()).toBe(false);
        expect(findAlert().exists()).toBe(false);
        expect(findEmptyState().exists()).toBe(false);

        expect(findRegistriesTable().props('registries')).toEqual(
          groupVirtualRegistries.group.mavenVirtualRegistries.nodes,
        );

        const { __typename, ...pageInfo } =
          groupVirtualRegistries.group.mavenVirtualRegistries.pageInfo;

        expect(findPagination().props()).toMatchObject(pageInfo);
      });

      it('emits `updateCount` event', async () => {
        await waitForPromises();

        expect(wrapper.emitted('updateCount')[0][0]).toBe(1);
      });
    });
  });

  describe('when the API returns an empty array', () => {
    it('displays the empty state', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistriesQuery, emptyMavenRegistriesHandler]],
      });

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);

      expect(findEmptyState().exists()).toBe(true);
      expect(findRegistriesTable().exists()).toBe(false);
    });
  });

  describe('when the API fails', () => {
    it('displays an error message', async () => {
      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, errorHandler]] });

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistriesTable().exists()).toBe(false);

      expect(findAlert().text()).toBe('GraphQL error');
      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenRegistriesList',
        error: mockError,
      });
    });
  });

  describe('when pagination URL query parameter exists', () => {
    it('passes the `after` params to the GraphQL query', async () => {
      setWindowLocation('?after=some_cursor');

      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, mavenRegistriesHandler]] });
      await nextTick();
      expect(mavenRegistriesHandler).toHaveBeenCalledWith({
        groupPath: defaultProvide.fullPath,
        first: PAGE_SIZE,
        after: 'some_cursor',
      });
    });

    it('passes the `before` params to the GraphQL query', async () => {
      setWindowLocation('?before=some_cursor');

      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, mavenRegistriesHandler]] });

      await nextTick();

      expect(mavenRegistriesHandler).toHaveBeenCalledWith({
        groupPath: defaultProvide.fullPath,
        last: PAGE_SIZE,
        before: 'some_cursor',
      });
    });
  });

  describe('when pagination component', () => {
    beforeEach(async () => {
      jest.spyOn(urlUtils, 'updateHistory');
      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, mavenRegistriesHandler]] });
      await waitForPromises();
    });

    it('emits `prev` event, GraphQL query is called with right parameters & URL is updated', async () => {
      await findPagination().vm.$emit('prev');

      expect(mavenRegistriesHandler).toHaveBeenLastCalledWith({
        groupPath: defaultProvide.fullPath,
        last: PAGE_SIZE,
        before: 'start',
      });

      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?before=start`,
      });
    });

    it('emits `next` event, GraphQL query is called with right parameters & URL is updated', async () => {
      await findPagination().vm.$emit('next');

      expect(mavenRegistriesHandler).toHaveBeenLastCalledWith({
        groupPath: defaultProvide.fullPath,
        first: PAGE_SIZE,
        after: 'end',
      });

      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?after=end`,
      });
    });
  });

  describe('on window `popstate` event', () => {
    it('calls the GraphQL query with right parameters', async () => {
      createComponent({ handlers: [[getMavenVirtualRegistriesQuery, mavenRegistriesHandler]] });
      await waitForPromises();

      expect(mavenRegistriesHandler).toHaveBeenCalledWith({
        groupPath: defaultProvide.fullPath,
        first: PAGE_SIZE,
      });

      setWindowLocation('?after=some_cursor');
      window.dispatchEvent(new PopStateEvent('popstate'));
      await nextTick();

      expect(mavenRegistriesHandler).toHaveBeenLastCalledWith({
        groupPath: defaultProvide.fullPath,
        first: PAGE_SIZE,
        after: 'some_cursor',
      });

      setWindowLocation('?before=some_cursor');
      window.dispatchEvent(new PopStateEvent('popstate'));
      await nextTick();

      expect(mavenRegistriesHandler).toHaveBeenLastCalledWith({
        groupPath: defaultProvide.fullPath,
        last: PAGE_SIZE,
        before: 'some_cursor',
      });
    });
  });
});
