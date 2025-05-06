import { GlBanner } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ExploreDuoCoreBanner from 'ee/ai/components/explore_duo_core_banner.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

Vue.use(VueApollo);

describe('ExploreDuoCoreBanner', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createComponent = () => {
    userCalloutDismissSpy = jest.fn();

    wrapper = mountExtended(ExploreDuoCoreBanner, {
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout: true,
        }),
      },
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findCta = () => wrapper.findByRole('link', { name: 'Explore GitLab Duo Core' });
  const findInstallationLink = () =>
    wrapper.findByRole('link', { name: 'install the GitLab extension in your IDE' });
  const findExploreLink = () =>
    wrapper.findByRole('link', { name: 'explore what you can do with GitLab Duo Core' });

  describe('banner content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('display the correct banner title and body', () => {
      const bannerText = findBanner().text();

      expect(bannerText).toContain('Get started with GitLab Duo');
      expect(bannerText).toContain(
        'You now have access to GitLab Duo Chat and Code Suggestions in supported IDEs. To start using these features',
      );
    });

    it('renders the correct cta button and links', () => {
      expect(findCta().exists()).toBe(true);
      expect(findCta().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/`,
      );

      expect(findInstallationLink().exists()).toBe(true);
      expect(findInstallationLink().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/#step-4-prepare-to-use-gitlab-duo-in-your-ide`,
      );

      expect(findExploreLink().exists()).toBe(true);
      expect(findExploreLink().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/gitlab_duo/#summary-of-gitlab-duo-features`,
      );
    });
  });

  describe('with dismissal', () => {
    beforeEach(() => {
      createComponent();
    });

    it('dismisses the banner when clicking the close button', () => {
      findBanner().vm.$emit('close');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });

    it('dismisses the banner when clicking the cta', () => {
      findBanner().vm.$emit('primary');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });
});
