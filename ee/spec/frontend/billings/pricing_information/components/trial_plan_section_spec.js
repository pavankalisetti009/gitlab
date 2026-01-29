import { shallowMount } from '@vue/test-utils';
import TrialPlanSection from 'ee/billings/pricing_information/components/trial_plan_section.vue';

describe('TrialPlanSection', () => {
  let wrapper;

  describe('with isNewTrialType prop set to true', () => {
    beforeEach(() => {
      wrapper = shallowMount(TrialPlanSection, {
        propsData: { isNewTrialType: true },
      });
    });

    it('displays the correct content with DAP messaging', () => {
      const text = wrapper.text();

      expect(text).toContain('Your group is on a trial of Gitlab Ultimate');
      expect(text).toContain(
        'Your trial includes all the benefits of Ultimate, plus access to advanced AI features.',
      );
      expect(text).toContain(
        'At the end of the trial, your subscription changes to Free. Upgrade to Premium to keep using advanced features.',
      );
    });
  });

  describe('with isNewTrialType prop set to false (default)', () => {
    beforeEach(() => {
      wrapper = shallowMount(TrialPlanSection);
    });

    it('displays the correct content with Duo Enterprise messaging', () => {
      const text = wrapper.text();

      expect(text).toContain('Your group is on a trial of Ultimate + GitLab Duo Enterprise');
      expect(text).toContain(
        'Your trial includes all the benefits of Ultimate, plus access to advanced AI features.',
      );
      expect(text).toContain(
        'At the end of the trial, your subscription changes to Free. Upgrade to Premium to keep using advanced features.',
      );
    });
  });
});
