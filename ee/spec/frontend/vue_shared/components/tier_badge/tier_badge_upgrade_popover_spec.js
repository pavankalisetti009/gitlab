import { GlPopover } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TierBadgePopover from 'ee/vue_shared/components/tier_badge/tier_badge_upgrade_popover.vue';
import { mockTracking } from 'helpers/tracking_helper';

describe('TierBadgeUpgradePopover', () => {
  let wrapper;

  const primaryCTALink = '#/groups/foobar-group/-/billings?source=overview-free-tier-highlight';
  const popoverTitle = 'Unlock advanced features';
  const popoverContent =
    'Get advanced features like GitLab Duo, merge approvals, epics, and code review analytics.';
  const primaryCTAText = 'Upgrade to unlock';

  const findPrimaryCTA = () => wrapper.findByTestId('tier-badge-popover-primary-cta');

  const createComponent = ({ props, provide } = { props: {}, provide: {} }) => {
    wrapper = mountExtended(TierBadgePopover, {
      provide: {
        primaryCtaLink: primaryCTALink,
        ...provide,
      },
      propsData: {
        target: document.createElement('div'),
        tier: 'Free',
        ...props,
      },
    });
  };

  describe('with content', () => {
    it('renders title and content`', () => {
      createComponent({ provide: { isProject: false } });

      const popover = wrapper.findComponent(GlPopover);
      expect(popover.props('title')).toBe(popoverTitle);
      expect(wrapper.text()).toContain(popoverContent);
    });

    describe('with CTAs', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the `Start a free trial` cta button', () => {
        expect(findPrimaryCTA().text()).toEqual(primaryCTAText);
        expect(findPrimaryCTA().attributes('href')).toEqual(primaryCTALink);
      });

      describe('tracking', () => {
        it('tracks primary CTA', () => {
          const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
          findPrimaryCTA().trigger('click');
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_start_trial_button', {
            label: 'tier_badge_upgrade',
          });
        });
      });
    });
  });
});
