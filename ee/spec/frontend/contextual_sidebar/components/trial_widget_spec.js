import { GlProgressBar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrialWidget from 'ee/contextual_sidebar/components/trial_widget.vue';
import { TRIAL_WIDGET } from 'ee/contextual_sidebar/components/constants';

describe('TrialWidget component', () => {
  let wrapper;

  const findRootElement = () => wrapper.findByTestId('trial-widget-root-element');
  const findCtaButton = () => wrapper.findByTestId('learn-about-features-btn');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findDismissButton = () => wrapper.findByTestId('dismiss-btn');

  const createComponent = (providers = {}) => {
    return shallowMountExtended(TrialWidget, {
      provide: {
        trialType: 'duo_enterprise',
        daysRemaining: 40,
        percentageComplete: 33,
        trialDiscoverPagePath: 'help_page_url',
        groupId: '1',
        featureId: '2',
        dismissEndpoint: '/dismiss',
        purchaseNowUrl: '/purchase',
        ...providers,
      },
    });
  };

  describe('rendered content', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders with the correct id', () => {
      expect(findRootElement().attributes('id')).toBe(TRIAL_WIDGET.containerId);
    });

    it('shows the expected days remaining text', () => {
      wrapper = createComponent({ daysRemaining: 20 });
      expect(wrapper.text()).toContain('20 days left in trial');
    });

    it('does not render the dismiss button during active trial', () => {
      expect(findDismissButton().exists()).toBe(false);
    });

    describe('dismissible class', () => {
      it('adds the class when all required props are present', () => {
        expect(findRootElement().classes()).toContain('js-expired-trial-widget');
      });

      it.each(['groupId', 'featureId', 'dismissEndpoint'])(
        'does not add the class when %s is missing',
        (prop) => {
          wrapper = createComponent({ [prop]: null });
          expect(findRootElement().classes()).not.toContain('js-expired-trial-widget');
        },
      );
    });

    describe('when trial is active', () => {
      beforeEach(() => {
        wrapper = createComponent({ daysRemaining: 30, percentageComplete: 50 });
      });

      it('renders the progress bar', () => {
        expect(findProgressBar().exists()).toBe(true);
      });

      it('renders the CTA button with correct text', () => {
        const ctaButton = findCtaButton();
        expect(ctaButton.exists()).toBe(true);
        expect(ctaButton.text()).toBe(TRIAL_WIDGET.i18n.learnMore);
      });
    });

    describe('when trial has expired', () => {
      beforeEach(() => {
        wrapper = createComponent({ daysRemaining: 0, percentageComplete: 100 });
      });

      it('shows correct title and body', () => {
        expect(wrapper.text()).toContain(
          TRIAL_WIDGET.trialTypes.duo_enterprise.widgetTitleExpiredTrial,
        );
        expect(wrapper.text()).toContain(TRIAL_WIDGET.i18n.seeUpgradeOptionsText);
      });

      it('renders the progress bar', () => {
        expect(findProgressBar().exists()).toBe(true);
      });

      it('renders the upgrade options text', () => {
        const ctaButton = findCtaButton();
        expect(ctaButton.exists()).toBe(true);
        expect(ctaButton.text()).toBe(TRIAL_WIDGET.i18n.seeUpgradeOptionsText);
      });

      it('renders the dismiss button', () => {
        expect(findDismissButton().exists()).toBe(true);
      });
    });
  });
});
