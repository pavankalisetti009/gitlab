import { GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import DataExplorer from 'ee/vue_shared/components/data_explorer/data_explorer.vue';
import DataExplorerApp from 'ee/analytics/data_explorer/components/app.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('DataExplorerApp', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    wrapper = mount(DataExplorerApp);
  });

  it('displays the page title', () => {
    expect(findPageHeading().props('heading')).toBe('Data explorer');
  });

  it('displays the page description', () => {
    expect(findPageHeading().text()).toContain(
      'Explore GitLab data in a single place. Learn more.',
    );
  });

  it('applies the correct route to the `Learn More` link', () => {
    expect(findPageHeading().findComponent(GlLink).attributes('href')).toBe(
      '/help/user/glql/_index',
    );
  });

  it('renders the data explorer', () => {
    expect(wrapper.findComponent(DataExplorer).exists()).toBe(true);
  });
});
