import { nextTick } from 'vue';
import { GlButton, GlTab } from '@gitlab/ui';
import DuoSelfHostedApp from 'ee/ai/duo_self_hosted/app.vue';
import FeatureSettings from 'ee/ai/duo_self_hosted/feature_settings/components/feature_settings.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { SELF_HOSTED_DUO_TABS, SELF_HOSTED_ROUTE_NAMES } from 'ee/ai/duo_self_hosted/constants';

describe('DuoSelfHostedApp', () => {
  let wrapper;
  const $router = { push: jest.fn() };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(DuoSelfHostedApp, {
      propsData: {
        ...props,
      },
      provide: {
        canManageInstanceModelSelection: false,
        canManageSelfHostedModels: true,
        isDedicatedInstance: false,
        ...provide,
      },
      mocks: {
        $router,
        $route: { params: {} },
      },
    });
  };

  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findFeatureSettingsTab = () => wrapper.findByTestId('ai-feature-settings-tab');
  const findSelfHostedModelsTab = () => wrapper.findByTestId('self-hosted-models-tab');
  const findAddModelButton = () => wrapper.findComponent(GlButton);

  it('has a title', () => {
    createComponent();

    const title = wrapper.findByTestId('self-hosted-title');
    expect(title.text()).toBe('Model configuration');
  });

  describe('description', () => {
    it('shows default description when user can manage self-hosted models', () => {
      createComponent({
        provide: {
          canManageSelfHostedModels: true,
        },
      });

      expect(wrapper.text()).toMatch(
        'Manage GitLab Duo by configuring and assigning self-hosted models to AI-native features.',
      );
    });

    it('shows Enterprise requirement message when user cannot manage self-hosted models', () => {
      createComponent({
        provide: {
          canManageSelfHostedModels: false,
        },
      });

      expect(wrapper.text()).toMatch(
        'View self-hosted models and configure AI-native features. A GitLab Duo Enterprise add-on is required to manage self-hosted models.',
      );
    });
  });

  describe('with instance-level model selection', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          canManageInstanceModelSelection: true,
        },
      });

      it('renders description', () => {
        expect(wrapper.text()).toMatch(
          'Configure and assign self-hosted models or GitLab managed models to AI-native features.',
        );
      });
    });
  });

  describe('Add self-hosted model button', () => {
    it('renders when user can manage self-hosted models', () => {
      createComponent({
        provide: {
          canManageSelfHostedModels: true,
        },
      });

      expect(findAddModelButton().exists()).toBe(true);
      expect(findAddModelButton().text()).toBe('Add self-hosted model');
      expect(findAddModelButton().props('to')).toEqual({ name: SELF_HOSTED_ROUTE_NAMES.NEW });
    });

    it('does not render when user cannot manage self-hosted models', () => {
      createComponent({
        provide: {
          canManageSelfHostedModels: false,
        },
      });

      expect(findAddModelButton().exists()).toBe(false);
    });
  });

  it.each`
    tabId                                       | expectedActiveTabValue
    ${SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS} | ${'0'}
    ${SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS}  | ${'1'}
    ${undefined}                                | ${'0'}
  `(
    'correctly sets active tab when tab id changes to $tabId',
    async ({ tabId, expectedActiveTabValue }) => {
      createComponent({ props: { tabId } });
      await nextTick();

      const tab = wrapper.findByTestId('self-hosted-duo-config-tabs');
      expect(tab.attributes('value')).toBe(expectedActiveTabValue);
    },
  );

  describe('Self-hosted models tab', () => {
    it('renders the correct name', () => {
      createComponent();

      expect(findSelfHostedModelsTab().text()).toBe('Self-hosted models');
    });

    it('navigates to self-hosted models when tab is clicked', async () => {
      createComponent({ props: { tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS } });

      findAllTabs().at(1).vm.$emit('click');

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: SELF_HOSTED_ROUTE_NAMES.MODELS });
    });
  });

  describe('Feature settings tab', () => {
    it('renders the correct name', () => {
      createComponent();

      expect(findFeatureSettingsTab().text()).toBe('AI-native features');
    });

    it('navigates to AI feature settings when tab is clicked', async () => {
      createComponent({ props: { tabId: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS } });

      findAllTabs().at(0).vm.$emit('click');

      await nextTick();

      expect($router.push).toHaveBeenCalledWith({ name: SELF_HOSTED_ROUTE_NAMES.FEATURES });
    });

    it('renders feature settings', () => {
      createComponent({
        props: { tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS },
      });

      expect(findFeatureSettings().exists()).toBe(true);
    });
  });

  describe('for Dedicated instance', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isDedicatedInstance: true,
        },
      });

      it('renders correct description', () => {
        expect(wrapper.text()).toMatch(
          'Configure and assign GitLab managed models to AI-native features.',
        );
      });

      it('does not render button to add new self-hosted model', () => {
        expect(findAddModelButton().exists()).toBe(false);
      });

      it('does not render self-hosted models tab', () => {
        expect(findSelfHostedModelsTab().exists()).toBe(false);
      });
    });
  });
});
