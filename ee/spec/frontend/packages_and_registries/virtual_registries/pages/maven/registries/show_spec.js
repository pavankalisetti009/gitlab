import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getMavenVirtualRegistryUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistriesDetailsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries/show.vue';
import MavenRegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/header.vue';
import MavenRegistryDetailsUpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/upstreams_list.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/registry_upstream_item.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { mavenVirtualRegistry } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

const mockMavenRegistryUpstreams = {
  data: {
    mavenVirtualRegistry: {
      ...mavenVirtualRegistry,
    },
  },
};

const defaultProvide = {
  groupPath: 'flightjs',
  registry: {
    id: 1,
    name: 'Registry 1',
    description: 'Maven Registry',
  },
  registryEditPath: '/groups/flightjs/-/virtual_registries/maven/1/edit',
  editUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id/edit',
  showUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id',
};

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const mockError = new Error('GraphQL error');

  const findUpstreamsList = () => wrapper.findComponent(MavenRegistryDetailsUpstreamsList);
  const findMavenRegistryDetailsHeader = () => wrapper.findComponent(MavenRegistryDetailsHeader);
  const findUpstreamRegistryItems = () => wrapper.findAllComponents(RegistryUpstreamItem);

  const mavenRegistryUpstreamsHandler = jest.fn().mockResolvedValue(mockMavenRegistryUpstreams);
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({ handlers = [] } = {}) => {
    wrapper = mountExtended(MavenRegistriesDetailsApp, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        ...defaultProvide,
      },
    });
  };

  describe('loading state', () => {
    it('sets loading prop on initial load', () => {
      createComponent();

      expect(findUpstreamsList().props('loading')).toBe(true);
    });

    it('does not set loading prop on subsequent loads', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();

      await findUpstreamsList().vm.$emit('upstreamCreated');

      expect(findUpstreamsList().props('loading')).toBe(false);
    });
  });

  describe('header', () => {
    it('renders MavenRegistryDetailsHeader component', () => {
      createComponent();

      expect(findMavenRegistryDetailsHeader().exists()).toBe(true);
    });
  });

  describe('upstreams list', () => {
    it('displays the upstream registries currently available', async () => {
      const upstreamsLength = mockMavenRegistryUpstreams.data.mavenVirtualRegistry.upstreams.length;

      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();

      expect(findUpstreamsList().props('loading')).toBe(false);
      expect(findUpstreamRegistryItems()).toHaveLength(upstreamsLength);
    });
  });

  describe('When a new upstream has been created', () => {
    it('refetches upstreams query', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();
      await findUpstreamsList().vm.$emit('upstreamCreated');

      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('with errors', () => {
    it('sends an error to Sentry', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, errorHandler]],
      });

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenRegistryDetailsApp',
        error: mockError,
      });
    });
  });

  describe('When an upstream has been reordered', () => {
    it('refetches upstreams query', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();
      await findUpstreamsList().vm.$emit('upstreamReordered');

      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('When an upstream has been removed', () => {
    it('refetches upstreams query', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();
      await findUpstreamsList().vm.$emit('upstreamRemoved');

      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('When an upstream has been associated', () => {
    it('refetches upstreams query', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, mavenRegistryUpstreamsHandler]],
      });

      await waitForPromises();
      await findUpstreamsList().vm.$emit('upstreamLinked');

      expect(mavenRegistryUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });
});
