import { shallowMount } from '@vue/test-utils';
import { GlTab, GlExperimentBadge } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_configuration/components/app.vue';
import ConfigureAttributes from 'ee/security_configuration/components/security_attributes/configure_attributes.vue';

describe('Group Security configuration', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findTab = () => wrapper.findComponent(GlTab);
  const findConfigureSecurityAttributes = () => wrapper.findComponent(ConfigureAttributes);

  const createComponent = () => {
    wrapper = shallowMount(App, {
      stubs: {
        GlTab,
      },
    });
  };

  it('renders page heading, tab, description, and attribute configuration', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe('Security configuration');
    expect(findTab().text()).toContain('Security attributes');
    expect(findTab().text()).toContain('Use security attributes to categorize projects');
    expect(findTab().findComponent(GlExperimentBadge).exists()).toBe(true);
    expect(findConfigureSecurityAttributes().exists()).toBe(true);
  });
});
