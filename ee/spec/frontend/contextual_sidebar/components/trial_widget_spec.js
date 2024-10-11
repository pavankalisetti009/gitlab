import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrialWidget from 'ee/contextual_sidebar/components/trial_widget.vue';
import { TRIAL_WIDGET } from 'ee/contextual_sidebar/components/constants';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';

describe('TrialWidget', () => {
  let wrapper;

  const createComponent = ({ provide = {}, ...options } = {}) => {
    wrapper = shallowMountExtended(TrialWidget, {
      provide: {
        trialType: 'duo_enterprise',
        daysRemaining: 40,
        percentageComplete: 33,
        trialDiscoverPagePath: 'help_page_url',
        groupId: '1',
        featureId: '2',
        dismissEndpoint: '/dismiss',
        purchaseNowUrl: '/purchase',
        ...provide,
      },
      ...options,
    });
  };

  const findProgressBar = () => wrapper.findComponent({ name: 'GlProgressBar' });
  const findCtaButton = () => wrapper.findComponent({ name: 'GlLink' });

  beforeEach(() => {
    useMockLocationHelper();
    mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  it('mounts', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('renders with the correct id', () => {
    createComponent();
    expect(wrapper.attributes('id')).toBe(TRIAL_WIDGET.containerId);
  });

  describe('computed properties', () => {
    it('computes widgetRemainingDays correctly', () => {
      createComponent({ provide: { daysRemaining: 20 } });
      expect(wrapper.vm.widgetRemainingDays).toBe('20 days left in trial');
    });

    it('computes widgetTitle correctly', () => {
      expect(wrapper.vm.widgetTitle).toBe('GitLab Duo Enterprise Trial');
    });

    it.each`
      daysRemaining | expected
      ${30}         | ${TRIAL_WIDGET.i18n.learnMore}
      ${10}         | ${TRIAL_WIDGET.i18n.upgradeText}
    `(
      'computes ctaText correctly when daysRemaining is $daysRemaining',
      ({ daysRemaining, expected }) => {
        createComponent({ provide: { daysRemaining } });
        expect(wrapper.vm.ctaText).toBe(expected);
      },
    );
  });

  describe('rendered content', () => {
    it('renders the correct days remaining when active', () => {
      createComponent({ provide: { daysRemaining: 20, percentageComplete: 50 } });
      expect(wrapper.text()).toContain('20 days left in trial');
    });

    it('renders the progress bar when active', () => {
      createComponent({ provide: { percentageComplete: 50 } });
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the progress bar when expired', () => {
      createComponent({ provide: { percentageComplete: 101 } });
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the CTA button with correct text when active', () => {
      createComponent({ provide: { percentageComplete: 50 } });
      const ctaButton = findCtaButton();
      expect(ctaButton.exists()).toBe(true);
      expect(ctaButton.text()).toBe(TRIAL_WIDGET.i18n.learnMore);
    });
  });
});
