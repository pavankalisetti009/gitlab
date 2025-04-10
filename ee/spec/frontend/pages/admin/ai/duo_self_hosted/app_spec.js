import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import DuoSelfHostedApp from 'ee/pages/admin/ai/duo_self_hosted/app.vue';
import FeatureSettingsTable from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/feature_settings_table.vue';
import ExpandedChatFeatureSettingsTable from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/expanded_chat_feature_settings_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { SELF_HOSTED_DUO_TABS } from 'ee/pages/admin/ai/duo_self_hosted/constants';

describe('DuoSelfHostedApp', () => {
  let wrapper;
  const $router = { push: jest.fn() };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(DuoSelfHostedApp, {
      propsData: {
        ...props,
      },
      provide: {
        duoChatSubFeaturesEnabled: false,
        ...provide,
      },
      mocks: {
        $router,
        $route: { params: {} },
      },
    });
  };

  const findTabs = () => wrapper.findByTestId('self-hosted-duo-config-tabs');
  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);
  const findExpandedChatFeatureSettingsTable = () =>
    wrapper.findComponent(ExpandedChatFeatureSettingsTable);
  const findFeatureSettingsTab = () => wrapper.findByTestId('ai-feature-settings-tab');
  const findSelfHostedModelsTab = () => wrapper.findByTestId('self-hosted-models-tab');
  const findAddModelButton = () => wrapper.findComponent(GlButton);

  it('has a title', () => {
    createComponent();

    const title = wrapper.findByTestId('self-hosted-title');
    expect(title.text()).toBe('GitLab Duo Self-Hosted');
  });

  it('has a description', () => {
    createComponent();

    expect(wrapper.text()).toMatch(
      'Manage GitLab Duo by configuring and assigning self-hosted models to AI-powered features.',
    );
  });

  it('has a button to add a new self-hosted model', () => {
    createComponent();

    expect(findAddModelButton().text()).toBe('Add self-hosted model');
  });

  describe('Self-hosted models tab', () => {
    it('renders the correct name', () => {
      createComponent();

      expect(findSelfHostedModelsTab().text()).toBe('Self-hosted models');
    });

    it('navigates to self-hosted models when tab is clicked', async () => {
      createComponent({ props: { tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS } });

      findTabs().vm.$emit('input', 1);

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: 'models' });
    });
  });

  describe('Feature settings tab', () => {
    it('renders the correct name', () => {
      createComponent();

      expect(findFeatureSettingsTab().text()).toBe('AI-powered features');
    });

    it('navigates to AI feature settings when tab is clicked', async () => {
      createComponent({ props: { tabId: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS } });

      findTabs().vm.$emit('input', 0);

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: 'features' });
    });

    describe('when Duo chat sub-features are disabled', () => {
      it('renders the feature settings table', () => {
        createComponent({ props: { tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS } });

        expect(findFeatureSettingsTable().exists()).toBe(true);
      });
    });

    describe('when Duo chat sub-features are enabled', () => {
      it('renders the expanded chat sub-features table', () => {
        createComponent({
          props: { tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS },
          provide: { duoChatSubFeaturesEnabled: true },
        });

        expect(findExpandedChatFeatureSettingsTable().exists()).toBe(true);
      });
    });
  });
});
