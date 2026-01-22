import { GlBanner, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoSecurityFeaturesBanner from 'ee/security_dashboard/components/shared/duo_security_features_banner.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import {
  DOC_PATH_VULNERABILITY_REPORT,
  DOC_PATH_SAST_FALSE_POSITIVE_DETECTION,
  DOC_PATH_DISMISSING_FALSE_POSITIVES,
} from 'ee/security_dashboard/constants';

describe('Duo security features banner component', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findAllLinks = () => wrapper.findAllComponents(GlLink);

  const createWrapper = ({
    glFeatures,
    shouldShowCallout = false,
    canAdminVulnerability = false,
    manageDuoSettingsPath = '/edit#js-duo-settings',
  } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(DuoSecurityFeaturesBanner, {
      provide: {
        glFeatures,
        canAdminVulnerability,
        manageDuoSettingsPath,
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        GlSprintf,
        GlLink,
      },
    });
  };

  describe('when aiExperimentSastFpDetection feature flag is enabled', () => {
    describe('when agenticSastVrUi feature flag is enabled', () => {
      it('displays the security features banner', () => {
        createWrapper({
          shouldShowCallout: true,
          canAdminVulnerability: true,
          manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: true,
          },
        });

        expect(findBanner().exists()).toBe(true);
        expect(findBanner().props('title')).toBe('GitLab Duo security features are here!');
        expect(findBanner().text()).toContain('identify false positives');
        expect(findBanner().text()).toContain('generate fixes for vulnerabilities');
        expect(findBanner().props('buttonText')).toBe('Manage settings');
        expect(findBanner().props('buttonLink')).toBe('/edit#js-gitlab-duo-settings');
        expect(findBanner().props('variant')).toBe('introduction');
      });

      it('renders documentation links correctly for security features banner', () => {
        createWrapper({
          shouldShowCallout: true,
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: true,
          },
        });

        const links = findAllLinks();
        expect(links).toHaveLength(2);

        expect(links.at(0).props('href')).toBe(DOC_PATH_SAST_FALSE_POSITIVE_DETECTION);
        expect(links.at(0).props('target')).toBe('_blank');
        expect(links.at(0).text()).toBe('identify false positives');

        expect(links.at(1).props('href')).toBe(DOC_PATH_DISMISSING_FALSE_POSITIVES);
        expect(links.at(1).props('target')).toBe('_blank');
        expect(links.at(1).text()).toBe('generate fixes for vulnerabilities');
      });

      it('displays learn more link when user cannot manage vulnerabilities', () => {
        createWrapper({
          shouldShowCallout: true,
          canAdminVulnerability: false,
          manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: true,
          },
        });
        expect(findBanner().props('buttonText')).toBe('Learn more');
        expect(findBanner().props('buttonLink')).toBe(DOC_PATH_VULNERABILITY_REPORT);
      });

      it('should handle closing the security features banner', () => {
        createWrapper({
          shouldShowCallout: true,
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: true,
          },
        });
        findBanner().vm.$emit('close');

        expect(userCalloutDismissSpy).toHaveBeenCalled();
      });
    });

    describe('when agenticSastVrUi feature flag is disabled', () => {
      it('displays the false positive detection banner', () => {
        createWrapper({
          shouldShowCallout: true,
          canAdminVulnerability: true,
          manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: false,
          },
        });

        expect(findBanner().exists()).toBe(true);
        expect(findBanner().props('title')).toBe(
          'GitLab Duo SAST false positive detection - available for a limited time in free Beta',
        );
        expect(findBanner().text()).toContain(
          'GitLab Duo can automatically review new critical and high severity',
        );
        expect(findBanner().text()).toContain('identify potential false positives');
        expect(findBanner().text()).toContain(
          'you can bulk dismiss the identified false positives',
        );
        expect(findBanner().props('buttonText')).toBe('Manage settings');
        expect(findBanner().props('buttonLink')).toBe('/edit#js-gitlab-duo-settings');
        expect(findBanner().props('variant')).toBe('introduction');
      });

      it('renders documentation links correctly for false positive detection banner', () => {
        createWrapper({
          shouldShowCallout: true,
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: false,
          },
        });

        const links = findAllLinks();
        expect(links).toHaveLength(2);

        expect(links.at(0).props('href')).toBe(DOC_PATH_SAST_FALSE_POSITIVE_DETECTION);
        expect(links.at(0).props('target')).toBe('_blank');
        expect(links.at(0).text()).toBe('identify potential false positives');

        expect(links.at(1).props('href')).toBe(DOC_PATH_DISMISSING_FALSE_POSITIVES);
        expect(links.at(1).props('target')).toBe('_blank');
        expect(links.at(1).text()).toBe('you can bulk dismiss the identified false positives');
      });

      it('displays learn more link when user cannot manage vulnerabilities', () => {
        createWrapper({
          shouldShowCallout: true,
          canAdminVulnerability: false,
          manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: false,
          },
        });
        expect(findBanner().props('buttonText')).toBe('Learn more');
        expect(findBanner().props('buttonLink')).toBe(DOC_PATH_VULNERABILITY_REPORT);
      });

      it('should handle closing the false positive detection banner', () => {
        createWrapper({
          shouldShowCallout: true,
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: false,
          },
        });
        findBanner().vm.$emit('close');

        expect(userCalloutDismissSpy).toHaveBeenCalled();
      });

      it('does not display the banner when the user callout is false', () => {
        createWrapper({
          shouldShowCallout: false,
          glFeatures: {
            aiExperimentSastFpDetection: true,
            agenticSastVrUi: false,
          },
        });
        expect(findBanner().exists()).toBe(false);
      });
    });
  });

  describe('when aiExperimentSastFpDetection feature flag is disabled', () => {
    beforeEach(() => {
      createWrapper({
        shouldShowCallout: true,
        glFeatures: {
          aiExperimentSastFpDetection: false,
        },
      });
    });

    it('does not display the banner', () => {
      expect(findBanner().exists()).toBe(false);
    });
  });
});
