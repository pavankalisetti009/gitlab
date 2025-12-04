import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlSkeletonLoader } from '@gitlab/ui';
import { cloneDeep } from 'lodash';
import mavenUpstreamSummaryPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_summary.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import LinkUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/link_upstream_form.vue';
import TestMavenUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/maven/shared/test_maven_upstream_button.vue';
import UpstreamSelector from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/upstream_selector.vue';
import getMavenUpstreamSummaryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_summary.query.graphql';
import { upstreamsResponse } from 'ee_jest/packages_and_registries/virtual_registries/mock_data';

Vue.use(VueApollo);

describe('LinkUpstreamForm', () => {
  let wrapper;

  const defaultProps = {
    linkedUpstreams: [],
    upstreamsCount: 1,
    initialUpstreams: upstreamsResponse.data,
  };

  const upstreamId = upstreamsResponse.data[0].id;
  const mockUpstream = mavenUpstreamSummaryPayload.data.virtualRegistriesPackagesMavenUpstream;

  const mavenUpstreamHandler = jest.fn().mockResolvedValue(mavenUpstreamSummaryPayload);

  const createComponent = ({
    handlers = [[getMavenUpstreamSummaryQuery, mavenUpstreamHandler]],
    props = defaultProps,
  } = {}) => {
    wrapper = shallowMountExtended(LinkUpstreamForm, {
      apolloProvider: createMockApollo(handlers),
      propsData: props,
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findUpstreamSelect = () => wrapper.findComponent(UpstreamSelector);
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findTestUpstreamButton = () => wrapper.findComponent(TestMavenUpstreamButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders form', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('renders upstream select', () => {
    expect(cloneDeep(findUpstreamSelect().props())).toEqual({
      upstreamsCount: defaultProps.upstreamsCount,
      linkedUpstreams: defaultProps.linkedUpstreams,
      initialUpstreams: defaultProps.initialUpstreams,
    });
  });

  it('renders empty upstream summary when upstream is not selected', () => {
    expect(wrapper.text()).toContain('To view summary, select an upstream.');
  });

  it('renders submit button', () => {
    expect(findSubmitButton().text()).toBe('Add upstream');
  });

  it('renders cancel button', () => {
    expect(findCancelButton().text()).toBe('Cancel');
  });

  it('does not render Test upstream button', () => {
    expect(findTestUpstreamButton().exists()).toBe(false);
  });

  it('does not call maven upstream graphql query', () => {
    expect(mavenUpstreamHandler).not.toHaveBeenCalled();
  });

  describe('when upstream is selected', () => {
    it('renders a loader', async () => {
      await findUpstreamSelect().vm.$emit('select', upstreamId);

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    describe('and API succeeds', () => {
      beforeEach(() => {
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('calls maven upstream graphql query', () => {
        expect(mavenUpstreamHandler).toHaveBeenCalledTimes(1);
        expect(mavenUpstreamHandler).toHaveBeenCalledWith({
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/3',
        });
      });

      it('renders upstream summary', async () => {
        await waitForPromises();

        expect(wrapper.text()).toContain('URL');
        expect(wrapper.text()).toContain(mockUpstream.url);
        expect(wrapper.text()).toContain('Description');
        expect(wrapper.text()).toContain(mockUpstream.description);
        expect(wrapper.text()).toContain('Artifact caching period');
        expect(wrapper.text()).toContain('24 hours');
        expect(wrapper.text()).toContain('Metadata caching period');
        expect(wrapper.text()).toContain('48 hours');
      });

      it('renders Test upstream button', () => {
        expect(findTestUpstreamButton().props('upstreamId')).toBe(3);
      });
    });

    describe('and API fails', () => {
      beforeEach(() => {
        createComponent({
          handlers: [
            [getMavenUpstreamSummaryQuery, jest.fn().mockResolvedValue(new Error('GraphQL error'))],
          ],
        });
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('renders alert message', async () => {
        await waitForPromises();
        expect(wrapper.text()).toContain('Failed to fetch upstream summary.');
      });

      it('renders Test upstream button', () => {
        expect(findTestUpstreamButton().props('upstreamId')).toBe(upstreamId);
      });
    });

    describe('when resolved upstream does not have description', () => {
      const upstreamResponseWithNullDescription = {
        data: {
          ...mavenUpstreamSummaryPayload.data,
          virtualRegistriesPackagesMavenUpstream: {
            ...mockUpstream,
            description: null,
          },
        },
      };

      beforeEach(async () => {
        createComponent({
          handlers: [
            [
              getMavenUpstreamSummaryQuery,
              jest.fn().mockResolvedValue(upstreamResponseWithNullDescription),
            ],
          ],
        });
        findUpstreamSelect().vm.$emit('select', upstreamId);
        await waitForPromises();
      });

      it('does not render `Description` label', () => {
        expect(wrapper.text()).toContain(mockUpstream.url);
        expect(wrapper.text()).not.toContain('Description');
      });
    });
  });

  describe('submit', () => {
    it('does not emit event if upstream is not selected', () => {
      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');

      expect(Boolean(submittedEvent)).toBe(false);
    });

    it('emits event if upstream is selected', async () => {
      await findUpstreamSelect().vm.$emit('select', upstreamId);

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(3);
    });
  });

  it('emits cancel event when Cancel button is clicked', () => {
    findCancelButton().vm.$emit('click');
    expect(Boolean(wrapper.emitted('cancel'))).toBe(true);
    expect(wrapper.emitted('cancel')[0]).toEqual([]);
  });
});
