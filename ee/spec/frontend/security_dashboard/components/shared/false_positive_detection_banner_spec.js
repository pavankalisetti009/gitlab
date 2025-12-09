import { GlBanner } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FalsePositiveDetectionBanner from 'ee/security_dashboard/components/shared/false_positive_detection_banner.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';

describe('False positive detection banner component', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const findFpDetectionBanner = () => wrapper.findComponent(GlBanner);

  const createWrapper = ({
    glFeatures,
    shouldShowCallout = false,
    canAdminVulnerability = false,
    manageDuoSettingsPath = '/edit#js-duo-settings',
  } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(FalsePositiveDetectionBanner, {
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
      },
    });
  };

  describe('when aiExperimentSastFpDetection feature flag is enabled', () => {
    it('displays the banner when the user callout is true', () => {
      createWrapper({
        shouldShowCallout: true,
        canAdminVulnerability: true,
        manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
      });

      expect(findFpDetectionBanner().exists()).toBe(true);
      expect(findFpDetectionBanner().props('title')).toBe(
        'GitLab Duo SAST false positive detection - available for a limited time in free Beta',
      );
      expect(findFpDetectionBanner().text()).toContain(
        'GitLab Duo automatically reviews critical and high severity SAST vulnerabilities to identify potential false positives. GitLab Duo assigns each false positive a confidence score and you can bulk dismiss the identified false positives in the vulnerability report. The service is enabled by default for free during the beta. You can adjust or turn off this feature in the GitLab Duo settings.',
      );
      expect(findFpDetectionBanner().props('buttonText')).toBe('Manage settings');
      expect(findFpDetectionBanner().props('buttonLink')).toBe('/edit#js-gitlab-duo-settings');
      expect(findFpDetectionBanner().props('variant')).toBe('introduction');
    });

    it('displays learn more link when user cannot manage vulnerabilities', () => {
      createWrapper({
        shouldShowCallout: true,
        canAdminVulnerability: false,
        manageDuoSettingsPath: '/edit#js-gitlab-duo-settings',
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
      });
      expect(findFpDetectionBanner().props('buttonText')).toBe('Learn more');
      expect(findFpDetectionBanner().props('buttonLink')).toBe(
        '/help/user/application_security/vulnerability_report/_index',
      );
    });

    it('does not display the banner when the user callout is false', () => {
      createWrapper({
        shouldShowCallout: false,
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
      });
      expect(findFpDetectionBanner().exists()).toBe(false);
    });

    it('should handle closing the banner', () => {
      createWrapper({
        shouldShowCallout: true,
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
      });
      findFpDetectionBanner().vm.$emit('close');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
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
      expect(findFpDetectionBanner().exists()).toBe(false);
    });
  });
});
