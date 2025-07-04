import { shallowMount } from '@vue/test-utils';
import { GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_configuration/components/app.vue';

describe('Group Security configuration', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findTab = () => wrapper.findComponent(GlTab);

  const createComponent = () => {
    wrapper = shallowMount(App, {
      provide: { groupFullPath: 'path/to/group' },
    });
  };

  it('renders page heading, tab, and description', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe('Security configuration');
    expect(findTab().attributes('title')).toBe('Security labels');
    expect(findTab().text()).toContain('Use security labels to classify projects');
  });
});
