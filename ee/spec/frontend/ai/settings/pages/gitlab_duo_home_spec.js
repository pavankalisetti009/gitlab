import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import DuoSelfHostedInfoCard from 'ee/ai/settings/components/duo_self_hosted_info_card.vue';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import { DUO_PRO } from 'ee/usage_quotas/code_suggestions/constants';

describe('GitLab Duo Home', () => {
  const mockSlotProps = {
    totalValue: 100,
    usageValue: 50,
    duoTier: DUO_PRO,
  };

  let wrapper;

  const createComponent = ({ isSaaS = true, canManageSelfHostedModels = false } = {}) => {
    wrapper = shallowMount(GitlabDuoHome, {
      propsData: {},
      provide: {
        isSaaS,
        canManageSelfHostedModels,
      },
      stubs: {
        CodeSuggestionsUsage: stubComponent(CodeSuggestionsUsage, {
          template: `
            <div>
              <slot name="health-check"></slot>
              <slot name="duo-card" v-bind="$options.mockSlotProps"></slot>
            </div>
          `,
          mockSlotProps,
        }),
      },
    });
  };

  const findCodeSuggestionsUsage = () => wrapper.findComponent(CodeSuggestionsUsage);
  const findHealthCheckList = () => wrapper.findComponent(HealthCheckList);
  const findDuoSeatUtilizationInfoCard = () => wrapper.findComponent(DuoSeatUtilizationInfoCard);
  const findDuoSelfHostedInfoCard = () => wrapper.findComponent(DuoSelfHostedInfoCard);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the components', () => {
      expect(findCodeSuggestionsUsage().exists()).toBe(true);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it(`passes the correct props to CodeSuggestionsUsage`, () => {
      expect(findCodeSuggestionsUsage().props()).toMatchObject({
        title: 'GitLab Duo',
        subtitle:
          'Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
        forceHideTitle: false,
      });
    });

    describe('when isSaaS is true', () => {
      it('does not render HealthCheckList', () => {
        expect(findHealthCheckList().exists()).toBe(false);
      });

      it('does not render DuoSelfHostedInfoCard', () => {
        expect(findDuoSelfHostedInfoCard().exists()).toBe(false);
      });
    });

    describe('when isSaaS is false', () => {
      it('renders HealthCheckList', () => {
        createComponent({ isSaaS: false });

        expect(findHealthCheckList().exists()).toBe(true);
      });

      describe('when canManageSelfHostedModels is true', () => {
        it('renders DuoSelfHostedInfoCard', () => {
          createComponent({ isSaaS: false, canManageSelfHostedModels: true });

          expect(findDuoSelfHostedInfoCard().exists()).toBe(true);
        });
      });
    });

    it('renders DuoSeatUtilizationInfoCard with correct props', () => {
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
      expect(findDuoSeatUtilizationInfoCard().props()).toMatchObject(mockSlotProps);
    });
  });
});
