import { GlBanner, GlLink, GlSprintf } from '@gitlab/ui';
import ExperimentFeaturesBanner from 'ee/security_orchestration/components/policies/banners/experiment_features_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ExperimentFeaturesBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ExperimentFeaturesBanner, {
      stubs: {
        GlBanner,
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findLink = () => wrapper.findComponent(GlLink);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);
  const findPrimaryBannerButton = () => wrapper.findByTestId('gl-banner-primary-button');

  it('renders banner with links', () => {
    expect(findLocalStorageSync().exists()).toBe(true);
    expect(findBanner().exists()).toBe(true);
    expect(findBanner().text()).toContain(
      'Introducing Pipeline Execution Policy Action experimental feature',
    );
    expect(findPrimaryBannerButton().attributes('href')).toBe(
      'https://gitlab.com/gitlab-org/gitlab/-/issues/434425',
    );
    expect(findLink().attributes('href')).toBe(
      '/help/user/application_security/policies/scan_execution_policies#experimental-features',
    );
  });

  it('dismisses the banner', async () => {
    await findBanner().vm.$emit('close');

    expect(findBanner().exists()).toBe(false);
  });
});
