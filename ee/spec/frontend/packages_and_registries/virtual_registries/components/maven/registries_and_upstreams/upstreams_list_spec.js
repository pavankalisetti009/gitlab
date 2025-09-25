import { GlEmptyState } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenUpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue';

describe('MavenUpstreamsList', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(MavenUpstreamsList, {});
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  it('renders GlEmpty state component', () => {
    createComponent();

    expect(findEmptyState().props()).toMatchObject({
      title: 'Connect Maven virtual registry to an upstream',
      description: 'Configure an upstream registry to manage Maven artifacts and cache entries.',
    });
  });

  it('emits `updateCount` event', () => {
    createComponent();

    expect(wrapper.emitted('updateCount')[0][0]).toBe(0);
  });
});
