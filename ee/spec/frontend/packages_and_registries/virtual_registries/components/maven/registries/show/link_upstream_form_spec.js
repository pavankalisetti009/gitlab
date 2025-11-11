import { GlForm, GlSkeletonLoader } from '@gitlab/ui';
import { cloneDeep } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LinkUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/link_upstream_form.vue';
import TestMavenUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/maven/shared/test_maven_upstream_button.vue';
import UpstreamSelector from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/upstream_selector.vue';
import { getMavenUpstream } from 'ee/api/virtual_registries_api';
import { mockUpstream, upstreamsResponse } from '../../../../mock_data';

jest.mock('ee/api/virtual_registries_api');

describe('LinkUpstreamForm', () => {
  let wrapper;

  const defaultProps = {
    linkedUpstreams: [],
    upstreamsCount: 1,
    initialUpstreams: upstreamsResponse.data,
  };

  const mavenUpstreamResponse = {
    data: { ...mockUpstream, cache_validity_hours: 24, metadata_cache_validity_hours: 48 },
  };

  const upstreamId = upstreamsResponse.data[0].id;

  const createComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(LinkUpstreamForm, {
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
      selectedUpstreamName: '',
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

  describe('when upstream is selected', () => {
    it('renders a loader', async () => {
      await findUpstreamSelect().vm.$emit('select', upstreamId);

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    describe('and API succeeds', () => {
      beforeEach(() => {
        getMavenUpstream.mockResolvedValue(mavenUpstreamResponse);
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('calls get upstream API', () => {
        expect(getMavenUpstream).toHaveBeenCalledWith({
          id: upstreamId,
        });
      });

      it('sets selected upstream name', () => {
        expect(findUpstreamSelect().props('selectedUpstreamName')).toBe(mockUpstream.name);
      });

      it('renders upstream summary', () => {
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
        expect(findTestUpstreamButton().props('upstreamId')).toBe(mockUpstream.id);
      });
    });

    describe('and API fails', () => {
      beforeEach(() => {
        getMavenUpstream.mockRejectedValue();
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('renders alert message', () => {
        expect(wrapper.text()).toContain('Failed to fetch upstream summary.');
      });

      it('does not render Test upstream button', () => {
        expect(findTestUpstreamButton().exists()).toBe(false);
      });
    });

    describe('when resolved upstream does not have description', () => {
      beforeEach(() => {
        getMavenUpstream.mockResolvedValue({
          data: {
            ...mavenUpstreamResponse.data,
            description: '',
          },
        });
        findUpstreamSelect().vm.$emit('select', upstreamId);
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
      getMavenUpstream.mockResolvedValue(mavenUpstreamResponse);
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
