import { nextTick } from 'vue';
import FeatureSettingsPage from 'ee/pages/admin/ai/custom_models/ai_feature_settings_page.vue';
import SelfHostedModelsPage from 'ee/pages/admin/ai/custom_models/self_hosted_models_page.vue';
import SelfHostedDuoConfiguration from 'ee/pages/admin/ai/custom_models/self_hosted_duo_configuration.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('SelfHostedDuoConfiguration', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(SelfHostedDuoConfiguration);
  };

  beforeEach(() => {
    createComponent();
  });

  const findFeatureSettingsTab = () => wrapper.findByTestId('ai-feature-settings-tab');
  const findSelfHostedModelsTab = () => wrapper.findByTestId('self-hosted-models-tab');
  const findFeatureSettingsPage = () => wrapper.findComponent(FeatureSettingsPage);
  const findSelfHostedModelsPage = () => wrapper.findComponent(SelfHostedModelsPage);

  it('has a title', () => {
    const title = wrapper.find('h2');

    expect(title.text()).toBe('Custom Models');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch(
      'Manage GitLab Duo by configuring and assigning self-hosted models to AI-powered features',
    );
  });

  it('has the correct tabs', () => {
    expect(findFeatureSettingsTab().text()).toBe('AI-powered features');
    expect(findSelfHostedModelsTab().text()).toBe('Self-hosted models');
  });

  describe('self-hosted models tab', () => {
    it('renders the self-hosted models page when tab clicked', async () => {
      findSelfHostedModelsTab().vm.$emit('click');

      await nextTick();

      expect(findSelfHostedModelsPage().exists()).toBe(true);
    });
  });

  describe('feature settings tab', () => {
    it('renders the feature settings page when tab clicked', async () => {
      findFeatureSettingsTab().vm.$emit('click');

      await nextTick();

      expect(findFeatureSettingsPage().exists()).toBe(true);
    });
  });
});
