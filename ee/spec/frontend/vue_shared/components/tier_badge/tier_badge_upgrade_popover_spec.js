import { GlPopover } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TierBadgeUpgradePopover from 'ee/vue_shared/components/tier_badge/tier_badge_upgrade_popover.vue';
import { mockTracking } from 'helpers/tracking_helper';

describe('TierBadgeUpgradePopover', () => {
  let wrapper;

  const primaryCTALink = '#/groups/foobar-group/-/billings?source=overview-free-tier-highlight';
  const popoverTitle = 'Unlock advanced features';
  const popoverContentWithDap =
    'Get advanced features like GitLab Duo Agent Platform, merge approvals, epics, and code review analytics.';
  const popoverContentWithoutDap =
    'Get advanced features like merge approvals, epics, and code review analytics.';
  const primaryCTAText = 'Upgrade to unlock';

  const findPrimaryCTA = () => wrapper.findByTestId('tier-badge-popover-primary-cta');
  const findPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = ({ props = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(TierBadgeUpgradePopover, {
      provide: {
        primaryCtaLink: primaryCTALink,
        glFeatures,
        ...provide,
      },
      propsData: {
        target: document.createElement('div'),
        tier: 'Free',
        ...props,
      },
    });
  };

  describe('with ultimate_trial_with_dap feature flag enabled', () => {
    describe('with content', () => {
      it('renders title and content with DAP', () => {
        createComponent({
          provide: { isProject: false },
          glFeatures: { ultimateTrialWithDap: true },
        });

        const popover = wrapper.findComponent(GlPopover);
        expect(popover.props('title')).toBe(popoverTitle);
        expect(wrapper.text()).toContain(popoverContentWithDap);
      });

      describe('with CTAs', () => {
        beforeEach(() => {
          createComponent({ glFeatures: { ultimateTrialWithDap: true } });
        });

        it('renders the `Start a free trial` cta button', () => {
          expect(findPrimaryCTA().text()).toEqual(primaryCTAText);
          expect(findPrimaryCTA().attributes('href')).toEqual(primaryCTALink);
        });

        describe('tracking', () => {
          it('tracks primary CTA', () => {
            const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
            findPrimaryCTA().trigger('click');
            expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_upgrade_button', {
              label: 'tier_badge_upgrade',
            });
          });

          it('tracks popover close', () => {
            const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
            findPopover().vm.$emit('close-button-clicked');
            expect(trackingSpy).toHaveBeenCalledWith(undefined, 'close', {
              label: 'tier_badge_upgrade',
            });
          });
        });
      });
    });
  });

  describe('with ultimate_trial_with_dap feature flag disabled', () => {
    describe('with content', () => {
      it('renders title and content without DAP', () => {
        createComponent({
          provide: { isProject: false },
          glFeatures: { ultimateTrialWithDap: false },
        });

        const popover = wrapper.findComponent(GlPopover);
        expect(popover.props('title')).toBe(popoverTitle);
        expect(wrapper.text()).toContain(popoverContentWithoutDap);
      });

      describe('with CTAs', () => {
        beforeEach(() => {
          createComponent({ glFeatures: { ultimateTrialWithDap: false } });
        });

        it('renders the `Start a free trial` cta button', () => {
          expect(findPrimaryCTA().text()).toEqual(primaryCTAText);
          expect(findPrimaryCTA().attributes('href')).toEqual(primaryCTALink);
        });

        describe('tracking', () => {
          it('tracks primary CTA', () => {
            const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
            findPrimaryCTA().trigger('click');
            expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_upgrade_button', {
              label: 'tier_badge_upgrade',
            });
          });

          it('tracks popover close', () => {
            const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
            findPopover().vm.$emit('close-button-clicked');
            expect(trackingSpy).toHaveBeenCalledWith(undefined, 'close', {
              label: 'tier_badge_upgrade',
            });
          });
        });
      });
    });
  });
});
