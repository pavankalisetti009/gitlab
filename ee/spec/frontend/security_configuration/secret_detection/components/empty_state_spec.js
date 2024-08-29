import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import EmptyState from 'ee/security_configuration/secret_detection/components/empty_state.vue';

describe('EmptyState', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(EmptyState, {
      stubs: {
        GlSprintf,
      },
    });
  };

  const findComponent = () => wrapper.findComponent(GlEmptyState);
  const findLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('mounts', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the correct title', () => {
    expect(findComponent().props('title')).toBe('No exclusions yet');
  });

  it('renders the correct primary button text', () => {
    expect(findComponent().props('primaryButtonText')).toBe('Add exclusion');
  });

  it('renders the documentation link in the description', () => {
    expect(findLink().exists()).toBe(true);
    expect(findLink().attributes('href')).toBe(
      '/help/user/application_security/secret_detection/index',
    );
  });
});
