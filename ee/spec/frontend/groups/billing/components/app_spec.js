import { shallowMount } from '@vue/test-utils';
import FreeTrialBillingApp from 'ee/groups/billing/components/app.vue';
import CurrentPlanHeader from 'ee/groups/billing/components/current_plan_header.vue';
import PremiumPlanHeader from 'ee/groups/billing/components/premium_plan_header.vue';
import FreePlanBillingHeader from 'ee/groups/billing/components/free_plan_billing_header.vue';
import FreePlanBilling from 'ee/groups/billing/components/free_plan_billing.vue';
import PremiumPlanBillingHeader from 'ee/groups/billing/components/premium_plan_billing_header.vue';
import PremiumPlanBilling from 'ee/groups/billing/components/premium_plan_billing.vue';
import UltimatePlanBillingHeader from 'ee/groups/billing/components/ultimate_plan_billing_header.vue';
import UltimatePlanBilling from 'ee/groups/billing/components/ultimate_plan_billing.vue';
import { mockBillingPageAttributes } from '../../mock_data';

describe('FreeTrialBillingApp', () => {
  let wrapper;

  const findCurrentPlanHeader = () => wrapper.findComponent(CurrentPlanHeader);
  const findPremiumPlanHeader = () => wrapper.findComponent(PremiumPlanHeader);
  const findFreePlanBillingHeader = () => wrapper.findComponent(FreePlanBillingHeader);
  const findFreePlanBilling = () => wrapper.findComponent(FreePlanBilling);
  const findPremiumPlanBillingHeader = () => wrapper.findComponent(PremiumPlanBillingHeader);
  const findPremiumPlanBilling = () => wrapper.findComponent(PremiumPlanBilling);
  const findUltimatePlanBillingHeader = () => wrapper.findComponent(UltimatePlanBillingHeader);
  const findUltimatePlanBilling = () => wrapper.findComponent(UltimatePlanBilling);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(FreeTrialBillingApp, {
      propsData: { ...mockBillingPageAttributes, ...props },
    });
  };

  it('renders components', () => {
    createComponent();

    expect(findCurrentPlanHeader().exists()).toBe(true);
    expect(findPremiumPlanHeader().exists()).toBe(true);
    expect(findFreePlanBillingHeader().exists()).toBe(true);
    expect(findPremiumPlanBillingHeader().props('ctaLabel')).toBe('Upgrade to Premium');
    expect(findPremiumPlanBillingHeader().props('upgradeToPremiumUrl')).toBe(
      '__upgrade_to_premium_url__',
    );
    expect(findPremiumPlanBillingHeader().props('trackingUrl')).toBe(
      '__upgrade_to_premium_tracking_url__',
    );
    expect(findUltimatePlanBillingHeader().props('ctaLabel')).toBe('Upgrade to Ultimate');
    expect(findUltimatePlanBillingHeader().props('upgradeToUltimateUrl')).toBe(
      '__upgrade_to_ultimate_url__',
    );
    expect(findUltimatePlanBillingHeader().props('trackingUrl')).toBe(
      '__upgrade_to_ultimate_tracking_url__',
    );
    expect(findFreePlanBilling().exists()).toBe(true);
    expect(findPremiumPlanBilling().exists()).toBe(true);
    expect(findUltimatePlanBilling().exists()).toBe(true);
  });

  describe('when trial is active', () => {
    it('renders components', () => {
      createComponent({ trialActive: true });

      expect(findPremiumPlanBillingHeader().props('ctaLabel')).toBe('Choose Premium');
      expect(findUltimatePlanBillingHeader().props('ctaLabel')).toBe('Choose Ultimate');
    });
  });
});
