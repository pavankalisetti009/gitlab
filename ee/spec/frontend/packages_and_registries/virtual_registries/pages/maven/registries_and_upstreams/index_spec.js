import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTab } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';

import getMavenUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import MavenRegistriesAndUpstreamsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries_and_upstreams/index.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_list.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { groupMavenUpstreamsCountResponse } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('MavenRegistriesAndUpstreamsApp', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org',
  };

  const mockError = new Error('GraphQL error');
  const mavenUpstreamsCountHandler = jest.fn().mockResolvedValue(groupMavenUpstreamsCountResponse);
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({
    handlers = [[getMavenUpstreamsCountQuery, mavenUpstreamsCountHandler]],
  } = {}) => {
    wrapper = shallowMountExtended(MavenRegistriesAndUpstreamsApp, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        ...defaultProvide,
      },
      stubs: {
        GlTabs: true,
        GlTab,
        UpstreamsList: stubComponent(UpstreamsList),
      },
    });
  };

  const findRegistriesTabTitle = () => wrapper.findByTestId('registries-tab-title');
  const findRegistriesCount = () => wrapper.findByTestId('registries-tab-counter-badge');
  const findRegistriesList = () => wrapper.findComponent(RegistriesList);
  const findUpstreamsTabTitle = () => wrapper.findByTestId('upstreams-tab-title');
  const findUpstreamsCount = () => wrapper.findByTestId('upstreams-tab-counter-badge');
  const findUpstreamsList = () => wrapper.findComponent(UpstreamsList);
  const findCleanupPolicyStatus = () => wrapper.findComponent(CleanupPolicyStatus);

  beforeEach(() => {
    createComponent();
  });

  it('renders registries tab', () => {
    expect(findRegistriesTabTitle().text()).toBe('Registries');
  });

  it('renders upstreams tab', () => {
    expect(findUpstreamsTabTitle().text()).toBe('Upstreams');
  });

  it('renders MavenRegistriesList component', () => {
    expect(findRegistriesList().exists()).toBe(true);
  });

  it('renders MavenUpstreamsList component', () => {
    expect(findUpstreamsList().props()).toStrictEqual({
      pageParams: {
        first: 20,
      },
      searchTerm: null,
    });
  });

  it('initially does not render registries count', () => {
    expect(findRegistriesCount().exists()).toBe(false);
  });

  it('initially does not render upstreams count', () => {
    expect(findUpstreamsCount().exists()).toBe(false);
  });

  it('renders CleanupPolicyStatus component', () => {
    expect(findCleanupPolicyStatus().exists()).toBe(true);
  });

  describe('when MavenRegistriesList emits `updateCount` event', () => {
    beforeEach(() => {
      findRegistriesList().vm.$emit('updateCount', 5);
    });

    it('renders registries count', () => {
      expect(findRegistriesCount().text()).toBe('5');
    });
  });

  it('calls upstreams count query with group path', () => {
    expect(mavenUpstreamsCountHandler).toHaveBeenCalledTimes(1);
    expect(mavenUpstreamsCountHandler).toHaveBeenCalledWith({
      groupPath: 'gitlab-org',
      upstreamName: null,
    });
  });

  describe('when UpstreamsList emits `submit` event with search term', () => {
    beforeEach(async () => {
      await findUpstreamsList().vm.$emit('submit', 'test');
    });

    it('sets searchTerm for MavenUpstreamsList component', () => {
      expect(findUpstreamsList().props('searchTerm')).toBe('test');
    });

    it('calls upstreams count query with upstream name', () => {
      expect(mavenUpstreamsCountHandler).toHaveBeenCalledTimes(2);
      expect(mavenUpstreamsCountHandler).toHaveBeenLastCalledWith({
        groupPath: 'gitlab-org',
        upstreamName: 'test',
      });
    });
  });

  describe('when UpstreamsList emits `page-change` event with next page params', () => {
    beforeEach(async () => {
      await findUpstreamsList().vm.$emit('page-change', { after: 'cursor' });
    });

    it('sets page params for MavenUpstreamsList component', () => {
      expect(findUpstreamsList().props('pageParams')).toMatchObject({ after: 'cursor', first: 20 });
    });

    it('does not refetch upstreams count query', () => {
      expect(mavenUpstreamsCountHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('when UpstreamsList emits `page-change` event with prev page params', () => {
    beforeEach(async () => {
      await findUpstreamsList().vm.$emit('page-change', { before: 'cursor' });
    });

    it('sets page params for MavenUpstreamsList component', () => {
      expect(findUpstreamsList().props('pageParams')).toMatchObject({ before: 'cursor', last: 20 });
    });

    it('does not refetch upstreams count query', () => {
      expect(mavenUpstreamsCountHandler).toHaveBeenCalledTimes(1);
    });

    describe('when UpstreamsList emits `upstream-deleted` event', () => {
      it('resets page params', async () => {
        await findUpstreamsList().vm.$emit('upstream-deleted');

        expect(findUpstreamsList().props('pageParams')).toStrictEqual({ first: 20 });
      });
    });

    describe('when UpstreamsList emits `search` event', () => {
      it('resets page params', async () => {
        await findUpstreamsList().vm.$emit('submit');

        expect(findUpstreamsList().props('pageParams')).toStrictEqual({ first: 20 });
      });
    });
  });

  describe('when upstreams count query returns response', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('renders upstreams count', () => {
      expect(findUpstreamsCount().text()).toBe('5');
    });
  });

  describe('when upstreams count query fails', () => {
    it('renders upstreams count', async () => {
      createComponent({
        handlers: [[getMavenUpstreamsCountQuery, errorHandler]],
      });

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenVirtualRegistriesAndUpstreamsApp',
        error: mockError,
      });
    });
  });

  describe('when UpstreamsList emits `upstream-deleted` event', () => {
    it('refetches upstreams count query', async () => {
      createComponent();

      await findUpstreamsList().vm.$emit('upstream-deleted');

      expect(mavenUpstreamsCountHandler).toHaveBeenCalledTimes(2);
    });
  });
});
