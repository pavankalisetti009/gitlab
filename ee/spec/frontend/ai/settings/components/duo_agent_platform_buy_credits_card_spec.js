import { GlIntersectionObserver } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformBuyCreditsCard from 'ee/ai/settings/components/duo_agent_platform_buy_credits_card.vue';
import { PROMO_URL } from '~/constants';
import { mockTracking } from 'helpers/tracking_helper';

describe('DuoAgentPlatformBuyCreditsCard', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DuoAgentPlatformBuyCreditsCard);
  };

  const findTalkToSalesBtn = () => wrapper.findByTestId('duo-agent-platform-talk-to-sales-action');

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays pre-title, title and description', () => {
      expect(wrapper.text()).toContain('Buy Credits');
      expect(wrapper.text()).toContain('GitLab Duo Agent Platform');
      expect(wrapper.text()).toContain(
        'Orchestrate AI agents across your entire software lifecycle to automate complex workflows, accelerate delivery, and keep your team in flow',
      );
    });

    it('renders cta for talking to sales', () => {
      expect(findTalkToSalesBtn().attributes('href')).toBe(`${PROMO_URL}/sales/`);
      expect(findTalkToSalesBtn().text()).toBe('Talk to Sales');
    });
  });

  describe('tracking', () => {
    let trackingSpy;
    const glIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    beforeEach(() => {
      createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('tracks page view on load', () => {
      glIntersectionObserver().vm.$emit('appear');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
        label: 'duo_agent_platform_buy_credits_card',
      });
    });

    describe('when talk to sales button is clicked', () => {
      it('tracks the "duo_agent_platform_talk_to_sales" event', async () => {
        await findTalkToSalesBtn().vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
          label: 'duo_agent_platform_talk_to_sales',
        });
      });
    });
  });
});
