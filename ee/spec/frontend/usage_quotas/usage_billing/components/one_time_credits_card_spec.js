import { GlSprintf } from '@gitlab/ui';
import OneTimeCreditsCard from 'ee/usage_quotas/usage_billing/components/one_time_credits_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('OneTimeCreditsCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    remainingCredits: 500,
    usedCredits: 1500,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(OneTimeCreditsCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('GitLab Credits - One-Time Waiver');
    });

    it('renders otc credits in metric prefix', () => {
      expect(wrapper.findByTestId('otc-credits').text()).toBe('1.5k');
    });

    it('renders remaining credits', () => {
      expect(wrapper.findByTestId('remaining-credits').text()).toBe('500');
    });
  });
});
