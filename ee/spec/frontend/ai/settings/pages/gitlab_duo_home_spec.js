import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import DuoModelsConfigurationInfoCard from 'ee/ai/settings/components/duo_models_configuration_info_card.vue';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import DuoWorkflowSettings from 'ee/ai/settings/components/duo_workflow_settings.vue';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
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
    customSlotProps = {},
    duoSelfHostedPath = '/admin/ai/duo_self_hosted',
    modelSwitchingEnabled = false,
    modelSwitchingPath = 'groups/test/-/settings/gitlab_duo/model_selection',
  } = {}) => {
    wrapper = shallowMount(GitlabDuoHome, {
      provide: {
        isSaaS,
        isAdminInstanceDuoHome,
        canManageSelfHostedModels,
        duoSelfHostedPath,
        modelSwitchingEnabled,
        modelSwitchingPath,
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
  const findDuoWorkflowSettings = () => wrapper.findComponent(DuoWorkflowSettings);

  describe('when SaaS', () => {
    describe('when its the admin instance Duo page', () => {
      it('renders the correct components', () => {
        createComponent({ isSaaS: true, isAdminInstanceDuoHome: true });

        expect(findCodeSuggestionsUsage().exists()).toBe(false);
        expect(findDuoSeatUtilizationInfoCard().exists()).toBe(false);
        expect(findDuoCoreUpgradeCard().exists()).toBe(false);
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

    describe('when canManageSelfHostedModels is true', () => {
      it('renders model switching card for Duo self-hosted', () => {
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
          path: '/admin/ai/duo_self_hosted',
        });
      });
    });

    describe('when canManageSelfHostedModels is false', () => {
      it('does not render Duo self-hosted card', () => {
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
  });

  it('renders DuoSeatUtilizationInfoCard with correct props', () => {
    createComponent();

    expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    expect(findDuoSeatUtilizationInfoCard().props()).toMatchObject(defaultSlotProps);
  });

  describe('template rendering', () => {
    it('renders the correct cards for Duo Pro', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_PRO } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it('renders the correct cards for Duo Enterprise', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_ENTERPRISE } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(false);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it('renders the correct cards for Duo Core', () => {
      createComponent({ customSlotProps: { activeDuoTier: DUO_CORE } });

      expect(findDuoCoreUpgradeCard().exists()).toBe(true);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(false);
    });
  });
});
