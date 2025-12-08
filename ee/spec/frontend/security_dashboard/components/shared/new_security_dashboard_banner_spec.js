import { GlBanner, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NewSecurityDashboardBanner from 'ee/security_dashboard/components/shared/new_security_dashboard_banner.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

describe('NewSecurityDashboardBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(NewSecurityDashboardBanner, {
      stubs: {
        GlSprintf,
      },
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findLink = () => wrapper.findComponent(GlLink);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the banner component', () => {
      expect(findBanner().exists()).toBe(true);
    });

    it('passes correct props to the banner', () => {
      expect(findBanner().props()).toMatchObject({
        title: 'Enhanced dashboard available',
        buttonText: 'Read more about the new dashboards',
        buttonLink: helpPagePath('/user/application_security/security_dashboard/_index.md', {
          anchor: 'new-security-dashboards',
        }),
        illustrationName: 'chart-bar-sm',
      });
    });

    it('renders the advanced search link with correct href', () => {
      expect(findLink().attributes('href')).toBe(
        helpPagePath('/user/search/advanced_search.md', {
          anchor: 'use-advanced-search',
        }),
      );
    });

    it('renders the link with correct text', () => {
      expect(findLink().text()).toBe('How do I enable advanced search?');
    });
  });
});
