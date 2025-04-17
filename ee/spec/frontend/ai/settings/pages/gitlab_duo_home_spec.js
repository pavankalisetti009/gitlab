import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import DuoWorkflowSettings from 'ee/ai/settings/components/duo_workflow_settings.vue';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import { DUO_PRO } from 'ee/usage_quotas/code_suggestions/constants';

describe('GitLab Duo Home', () => {
  const mockSlotProps = {
    totalValue: 100,
    usageValue: 50,
    duoTier: DUO_PRO,
  };

  let wrapper;

  const createComponent = ({ isSaaS = true } = {}) => {
    wrapper = shallowMount(GitlabDuoHome, {
      propsData: {},
      provide: {
        isSaaS,
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
  const findDuoWorkflowSettings = () => wrapper.findComponent(DuoWorkflowSettings);

  describe('component rendering', () => {
    describe('when isSaaS is false', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false });
      });

      it('renders DuoWorkflowSettings but not CodeSuggestionsUsage', () => {
        expect(findCodeSuggestionsUsage().exists()).toBe(true);
        expect(findDuoWorkflowSettings().exists()).toBe(false);
      });

      it('renders the components', () => {
        expect(findCodeSuggestionsUsage().exists()).toBe(true);
        expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
        expect(findHealthCheckList().exists()).toBe(true);
        expect(findDuoWorkflowSettings().exists()).toBe(false);
      });

      it(`passes the correct props to CodeSuggestionsUsage`, () => {
        expect(findCodeSuggestionsUsage().props()).toMatchObject({
          title: 'GitLab Duo',
          subtitle:
            'Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
          forceHideTitle: false,
        });
      });

      it('renders DuoSeatUtilizationInfoCard with correct props', () => {
        expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
        expect(findDuoSeatUtilizationInfoCard().props()).toMatchObject(mockSlotProps);
      });
    });

    describe('when isSaaS is true', () => {
      beforeEach(() => {
        createComponent({
          isSaaS: true,
        });
      });

      it('renders DuoWorkflowSettings but not CodeSuggestionsUsage', () => {
        expect(findDuoWorkflowSettings().exists()).toBe(true);
        expect(findCodeSuggestionsUsage().exists()).toBe(false);
        expect(findDuoSeatUtilizationInfoCard().exists()).toBe(false);
        expect(findHealthCheckList().exists()).toBe(false);
      });

      it('passes the correct props to DuoWorkflowSettings', () => {
        expect(findDuoWorkflowSettings().props('title')).toBe('GitLab Duo');
        expect(findDuoWorkflowSettings().props('subtitle')).toBe(
          'Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
        );
      });
    });
  });
});
