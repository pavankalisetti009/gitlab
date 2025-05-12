import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ServiceAccountsBreadcrumb from 'ee/service_accounts/components/service_accounts_breadcrumb.vue';

describe('ServiceAccountsBreadcrumb', () => {
  let wrapper;

  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);

  const createComponent = ({ $route = {} } = {}) => {
    wrapper = shallowMount(ServiceAccountsBreadcrumb, {
      mocks: {
        $route,
      },
    });
  };

  it('renders the root `Service Accounts` breadcrumb on Service Accounts page', () => {
    createComponent();

    expect(findBreadcrumb().props('items')).toEqual([{ text: 'Service accounts', to: '/' }]);
  });

  it('renders the `Personal access tokens` breadcrumb on access token page', () => {
    createComponent({ $route: { name: 'access_tokens', path: '/72/access_tokens' } });

    expect(findBreadcrumb().props('items')).toEqual([
      { text: 'Service accounts', to: '/' },
      { text: 'Personal access tokens', to: '/72/access_tokens' },
    ]);
  });
});
