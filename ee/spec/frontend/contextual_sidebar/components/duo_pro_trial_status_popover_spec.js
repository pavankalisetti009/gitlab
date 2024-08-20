import { GlPopover } from '@gitlab/ui';
import { GlBreakpointInstance } from '@gitlab/ui/dist/utils';
import { nextTick } from 'vue';
import timezoneMock from 'timezone-mock';
import DuoProTrialStatusPopover from 'ee/contextual_sidebar/components/duo_pro_trial_status_popover.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

import {
  DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
  DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY,
  WIDGET_CONTAINER_ID,
} from 'ee/contextual_sidebar/components/constants';

describe('DuoProTrialStatusPopover component', () => {
  let wrapper;
  let trackingSpy;

  const defaultDaysRemaining = 20;

  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findPurchaseNowBtn = () => wrapper.findByTestId('purchase-now-btn');
  const findLearnAboutFeaturesBtn = () => wrapper.findByTestId('learn-about-features-btn');
  const handRaiseLeadBtn = () => wrapper.findComponent(HandRaiseLeadButton);

  const expectTracking = ({ action, ...options } = {}) => {
    const category = options.category || DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY;

    return expect(trackingSpy).toHaveBeenCalledWith(category, action, { category, ...options });
  };

  const createComponent = ({ providers = {}, mountFn = shallowMountExtended, stubs = {} } = {}) => {
    wrapper = mountFn(DuoProTrialStatusPopover, {
      provide: {
        daysRemaining: defaultDaysRemaining,
        planName: 'Ultimate',
        purchaseNowUrl: 'usage_quota/path-for/group',
        targetId: 'target-element-identifier',
        trialEndDate: new Date('2021-02-21'),
        learnAboutButtonUrl: 'add_ons/discover_duo_pro',
        ...providers,
      },
      stubs,
    });
  };

  beforeEach(() => {
    createComponent();
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('title', () => {
    it('correctly displays when days remaining is 1', () => {
      createComponent({ providers: { daysRemaining: 1 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain("You've got 1 day left in your GitLab Duo Pro trial");
    });

    it('correct displays when days remaining is 60', () => {
      createComponent({ providers: { daysRemaining: 60 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain("You've got 60 days left in your GitLab Duo Pro trial");
    });

    it('correctly displays with an expired trial', () => {
      createComponent({ providers: { daysRemaining: -5 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain('You no longer have access to GitLab Duo Pro features');
    });
  });

  describe('popover props/attributes', () => {
    it('does not set width when showing active trial status', () => {
      expect(findGlPopover().props('cssClasses')).toEqual(['gl-p-2']);
    });

    it('sets the container', () => {
      expect(findGlPopover().props('container')).toEqual(WIDGET_CONTAINER_ID);
    });

    it('sets the target', () => {
      expect(findGlPopover().props('target')).toEqual(WIDGET_CONTAINER_ID);
    });
  });

  describe('content', () => {
    it('displays correct message when namespace is in active trial', () => {
      createComponent({ providers: { daysRemaining: 5 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain('To continue using features in GitLab Duo Pro');
    });

    it('displays correct message with an expired trial', () => {
      createComponent({ providers: { daysRemaining: -5 }, mountFn: mountExtended });

      expect(wrapper.text()).toContain(
        'To regain access to features like Code Suggestions and Chat',
      );
    });
  });

  describe('buttons', () => {
    it('sets correct props to the hand raise lead button', () => {
      const buttonAttributes = {
        size: 'small',
        variant: 'confirm',
        category: 'secondary',
        class: 'gl-w-full',
        buttonTextClasses: 'gl-text-sm',
        href: '#',
        'data-testid': 'duo-pro-trial-popover-hand-raise-lead-button',
      };

      expect(handRaiseLeadBtn().props()).toMatchObject({
        buttonAttributes,
        glmContent: 'duo-pro-trial-status-show-group',
        ctaTracking: {
          category: DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY,
          action: 'click_button',
          label: 'contact_sales',
        },
      });
    });

    it('sets correct tracking props with an expired trial', () => {
      createComponent({ providers: { daysRemaining: -5 } });

      expect(handRaiseLeadBtn().props()).toMatchObject({
        ctaTracking: {
          category: DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY,
          action: 'click_button',
          label: 'contact_sales',
        },
      });
    });

    describe('purchase now button', () => {
      const options = {
        action: 'click_button',
        label: 'purchase_now',
      };

      it('tracks when the button is clicked', () => {
        findPurchaseNowBtn().vm.$emit('click');

        expectTracking(options);
      });

      describe('with an expired trial', () => {
        it('tracks when the button is clicked', () => {
          createComponent({ providers: { daysRemaining: -5 } });

          findPurchaseNowBtn().vm.$emit('click');

          expectTracking({ ...options, category: DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY });
        });
      });
    });

    describe('learn about button', () => {
      const options = {
        action: 'click_button',
        label: 'learn_about_features',
      };

      it('tracks when the button is clicked', () => {
        findLearnAboutFeaturesBtn().vm.$emit('click');

        expectTracking(options);
      });

      it('renders the button label', () => {
        expect(findLearnAboutFeaturesBtn().text()).toBe('Learn about features');
      });

      it('sets correct attributes', () => {
        const learnAboutFeatures = findLearnAboutFeaturesBtn();

        expect(learnAboutFeatures.attributes('href')).toBe('add_ons/discover_duo_pro');
        expect(learnAboutFeatures.attributes('target')).toBe(undefined);
      });

      describe('with an expired trial', () => {
        beforeEach(() => {
          createComponent({ providers: { daysRemaining: -5 } });
        });

        it('tracks when the button is clicked', () => {
          findLearnAboutFeaturesBtn().vm.$emit('click');

          expectTracking({
            ...options,
            category: DUO_PRO_TRIAL_EXPIRED_POPOVER_TRACKING_CATEGORY,
            label: 'learn_about_duo_pro',
          });
        });

        it('renders the button label', () => {
          expect(findLearnAboutFeaturesBtn().text()).toBe('Learn about GitLab Duo');
        });
      });
    });
  });

  describe('correct date in different timezone', () => {
    beforeEach(() => {
      timezoneMock.register('US/Pacific');
    });

    afterEach(() => {
      timezoneMock.unregister();
    });

    it('converts date correctly to UTC', () => {
      createComponent({ mountFn: mountExtended });

      expect(wrapper.findByText('February 21').exists()).toBe(true);
    });
  });

  describe('methods', () => {
    describe('updateDisabledState', () => {
      it.each`
        bp      | isDisabled
        ${'xs'} | ${'true'}
        ${'sm'} | ${'true'}
        ${'md'} | ${undefined}
        ${'lg'} | ${undefined}
        ${'xl'} | ${undefined}
      `(
        'sets disabled to `$isDisabled` when the breakpoint is "$bp"',
        async ({ bp, isDisabled }) => {
          jest.spyOn(GlBreakpointInstance, 'getBreakpointSize').mockReturnValue(bp);

          window.dispatchEvent(new Event('resize'));
          await nextTick();

          expect(findGlPopover().attributes().disabled).toBe(isDisabled);
        },
      );
    });

    describe('onShown', () => {
      it('dispatches tracking event', () => {
        const options = {
          action: 'render_popover',
        };

        findGlPopover().vm.$emit('shown');

        expectTracking(options);
      });
    });
  });
});
