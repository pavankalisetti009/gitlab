import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import DuoModelsConfigurationInfoCard from 'ee/ai/settings/components/duo_models_configuration_info_card.vue';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import DuoAgentPlatformBuyCreditsCard from 'ee/ai/settings/components/duo_agent_platform_buy_credits_card.vue';
import DuoWorkflowSettings from 'ee/ai/settings/components/duo_workflow_settings.vue';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import DuoUsageAnalyticsCard from 'ee/ai/settings/components/duo_usage_analytics_card.vue';
import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE } from 'ee/constants/duo';

describe('GitLab Duo Home', () => {
  const defaultSlotProps = {
    totalValue: 100,
    usageValue: 50,
    activeDuoTier: DUO_PRO,
    addOnPurchases: [{ name: DUO_PRO }],
  };

  let wrapper;

  const createComponent = ({
    isSaaS = true,
    isAdminInstanceDuoHome = false,
    canManageSelfHostedModels = false,
    canManageInstanceModelSelection = false,
    customSlotProps = {},
    duoSelfHostedPath = '/admin/gitlab_duo/self_hosted',
    modelSwitchingEnabled = false,
    modelSwitchingPath = 'groups/test/-/settings/gitlab_duo/model_selection',
    gitlabCreditsDashboardPath = '',
    glFeatures = {},
  } = {}) => {
    wrapper = shallowMount(GitlabDuoHome, {
      provide: {
        isSaaS,
        isAdminInstanceDuoHome,
        canManageSelfHostedModels,
        duoSelfHostedPath,
        modelSwitchingEnabled,
        modelSwitchingPath,
        canManageInstanceModelSelection,
        gitlabCreditsDashboardPath,
        glFeatures,
      },
      stubs: {
        CodeSuggestionsUsage: stubComponent(CodeSuggestionsUsage, {
          template: `
            <div>
              <slot name="health-check"></slot>
              <slot name="duo-card" v-bind="$options.slotProps"></slot>
            </div>
          `,
          slotProps: {
            ...defaultSlotProps,
            ...customSlotProps,
          },
        }),
      },
    });
  };

  const findCodeSuggestionsUsage = () => wrapper.findComponent(CodeSuggestionsUsage);
  const findHealthCheckList = () => wrapper.findComponent(HealthCheckList);
  const findDuoSeatUtilizationInfoCard = () => wrapper.findComponent(DuoSeatUtilizationInfoCard);
  const findDuoModelsConfigurationCard = () =>
    wrapper.findComponent(DuoModelsConfigurationInfoCard);
  const findDuoCoreUpgradeCard = () => wrapper.findComponent(DuoCoreUpgradeCard);
  const findDuoAgentPlatformBuyCreditsCard = () =>
    wrapper.findComponent(DuoAgentPlatformBuyCreditsCard);
  const findDuoWorkflowSettings = () => wrapper.findComponent(DuoWorkflowSettings);

  describe('when SaaS', () => {
    describe('when its the admin instance Duo page', () => {
      it('renders the correct components', () => {
        createComponent({ isSaaS: true, isAdminInstanceDuoHome: true });

        expect(findCodeSuggestionsUsage().exists()).toBe(false);
        expect(findDuoSeatUtilizationInfoCard().exists()).toBe(false);
        expect(findDuoCoreUpgradeCard().exists()).toBe(false);
        expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(false);
        expect(findDuoModelsConfigurationCard().exists()).toBe(false);
        expect(findHealthCheckList().exists()).toBe(false);
        expect(findDuoWorkflowSettings().exists()).toBe(true);
      });
    });

    describe('when its the group settings Duo page', () => {
      beforeEach(() => {
        createComponent({ provide: { isSaaS: true, isAdminInstanceDuoHome: false } });
      });

      it('renders the correct base components', () => {
        expect(findCodeSuggestionsUsage().exists()).toBe(true);
        expect(findHealthCheckList().exists()).toBe(false);
        expect(findDuoWorkflowSettings().exists()).toBe(false);
      });

      it('passes the correct props to `CodeSuggestionsUsage`', () => {
        expect(findCodeSuggestionsUsage().props()).toMatchObject({
          title: 'GitLab Duo',
          subtitle:
            'Monitor, manage, and customize AI-powered features to ensure efficient utilization and alignment.',
        });
      });

      describe('when modelSwitchingEnabled is true', () => {
        it('renders model switching card for model selection', () => {
          createComponent({
            isSaaS: true,
            isAdminInstanceDuoHome: false,
            modelSwitchingEnabled: true,
          });

          const modelSwitchingCard = findDuoModelsConfigurationCard();
          expect(modelSwitchingCard.props('duoModelsConfigurationProps')).toMatchObject({
            header: 'Model Selection',
            description: 'Assign models to AI-native features.',
            buttonText: 'Configure features',
            path: 'groups/test/-/settings/gitlab_duo/model_selection',
          });
        });
      });

      describe('when modelSwitchingEnabled is false', () => {
        it('does not render model switching card', () => {
          createComponent({
            isSaaS: true,
            isAdminInstanceDuoHome: false,
            modelSwitchingEnabled: false,
          });

          expect(findDuoModelsConfigurationCard().exists()).toBe(false);
        });
      });
    });
  });

  describe('when self-managed', () => {
    describe('when admin instance Duo page', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false, isAdminInstanceDuoHome: true });
      });

      it('renders the correct base components', () => {
        expect(findCodeSuggestionsUsage().exists()).toBe(true);
        expect(findHealthCheckList().exists()).toBe(true);
        expect(findDuoWorkflowSettings().exists()).toBe(true);
      });

      it('passes the correct props to `CodeSuggestionsUsage`', () => {
        expect(findCodeSuggestionsUsage().props()).toMatchObject({
          title: 'GitLab Duo',
          subtitle:
            'Monitor, manage, and customize AI-powered features to ensure efficient utilization and alignment.',
        });
      });
    });

    describe('model switching card', () => {
      describe('with Duo Self-Hosted', () => {
        it('renders card when `canManageSelfHostedModels` is true', () => {
          createComponent({
            isSaaS: false,
            isAdminInstanceDuoHome: true,
            canManageSelfHostedModels: true,
          });

          const duoSelfHostedCard = findDuoModelsConfigurationCard();
          expect(duoSelfHostedCard.props('duoModelsConfigurationProps')).toMatchObject({
            header: 'GitLab Duo Self-Hosted',
            description: 'Assign self-hosted models to specific AI-native features.',
            buttonText: 'Configure GitLab Duo Self-Hosted',
            path: '/admin/gitlab_duo/self_hosted',
          });
        });

        it('does not render card when `canManageSelfHostedModels` is false', () => {
          createComponent({
            provide: {
              isSaaS: false,
              isAdminInstanceDuoHome: true,
              canManageSelfHostedModels: false,
            },
          });

          expect(findDuoModelsConfigurationCard().exists()).toBe(false);
        });
      });

      describe('with instance-level model selection', () => {
        it('renders the card when `canManageInstanceModelSelection` is true', () => {
          createComponent({
            isSaaS: false,
            isAdminInstanceDuoHome: true,
            canManageInstanceModelSelection: true,
          });

          const duoSelfHostedCard = findDuoModelsConfigurationCard();
          expect(duoSelfHostedCard.props('duoModelsConfigurationProps')).toMatchObject({
            header: 'GitLab Duo Model Selection',
            description:
              'Assign self-hosted or cloud-connected models to use with specific AI-native features.',
            buttonText: 'Configure models for GitLab Duo',
            path: '/admin/gitlab_duo/self_hosted',
          });
        });

        it('does not render the card when `canManageInstanceModelSelection` is false', () => {
          createComponent({
            isSaaS: false,
            isAdminInstanceDuoHome: true,
            canManageInstanceModelSelection: false,
          });

          expect(findDuoModelsConfigurationCard().exists()).toBe(false);
        });
      });

      it('renders the card when `canManageInstanceModelSelection` and `canManageSelfHostedModels` are true', () => {
        createComponent({
          isSaaS: false,
          isAdminInstanceDuoHome: true,
          canManageSelfHostedModels: true,
          canManageInstanceModelSelection: true,
        });

        const duoSelfHostedCard = findDuoModelsConfigurationCard();
        expect(duoSelfHostedCard.props('duoModelsConfigurationProps')).toMatchObject({
          header: 'GitLab Duo Model Selection',
          description:
            'Assign self-hosted or cloud-connected models to use with specific AI-native features.',
          buttonText: 'Configure models for GitLab Duo',
          path: '/admin/gitlab_duo/self_hosted',
        });
      });
    });
  });

  it('renders DuoSeatUtilizationInfoCard with correct props', () => {
    createComponent();

    expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    expect(findDuoSeatUtilizationInfoCard().props()).toMatchObject(defaultSlotProps);
  });

  describe('duo usage analytics card', () => {
    const findDuoUsageAnalyticsCard = () => wrapper.findComponent(DuoUsageAnalyticsCard);

    it('is rendered when gitlabCreditsDashboardPath is provided', () => {
      createComponent({ gitlabCreditsDashboardPath: '/due-usage-url' });
      expect(findDuoUsageAnalyticsCard().exists()).toBe(true);
    });

    it('is not rendered when gitlabCreditsDashboardPath is absent', () => {
      createComponent({ gitlabCreditsDashboardPath: null });
      expect(wrapper.findComponent(DuoUsageAnalyticsCard).exists()).toBe(false);
    });
  });

  describe('template rendering', () => {
    it('renders the correct cards for Duo Pro', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_PRO } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(false);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it('renders the correct cards for Duo Enterprise', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_ENTERPRISE } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(false);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it('renders the correct cards for Duo Core on group page', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_CORE } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(true);
      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(false);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(false);
    });

    it('renders the DuoAgentPlatformBuyCreditsCard for Duo Core on self-managed admin page', () => {
      createComponent({
        isSaaS: false,
        customSlotProps: { activeDuoTier: DUO_CORE },
      });

      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(true);
      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
    });

    it('renders DuoAgentPlatformBuyCreditsCard for Duo Core on SaaS group page with feature flag enabled', () => {
      createComponent({
        isSaaS: true,
        customSlotProps: { activeDuoTier: DUO_CORE },
        glFeatures: { ultimateTrialWithDap: true },
      });

      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(true);
      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
    });

    it('renders DuoCoreUpgradeCard for Duo Core on SaaS group page without feature flag', () => {
      createComponent({
        isSaaS: true,
        customSlotProps: { activeDuoTier: DUO_CORE },
        glFeatures: { ultimateTrialWithDap: false },
      });

      expect(findDuoAgentPlatformBuyCreditsCard().exists()).toBe(false);
      expect(findDuoCoreUpgradeCard().exists()).toBe(true);
    });
  });
});
