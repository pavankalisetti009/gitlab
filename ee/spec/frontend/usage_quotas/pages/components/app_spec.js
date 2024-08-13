import { shallowMount } from '@vue/test-utils';
import PagesDeployments from 'ee/usage_quotas/pages/components/app.vue';
import PagesDeploymentsStats from 'ee/usage_quotas/pages/components/stats.vue';

describe('PagesDeployments', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(PagesDeployments);
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the heading', () => {
    const heading = wrapper.find('h2');
    expect(heading.exists()).toBe(true);
    expect(heading.text()).toBe('Pages deployments');
  });

  it('renders the PagesDeploymentStats component', () => {
    const statsComponent = wrapper.findComponent(PagesDeploymentsStats);
    expect(statsComponent.exists()).toBe(true);
  });
});
