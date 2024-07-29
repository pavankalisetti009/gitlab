import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { WIDGET, WIDGET_CONTAINER_ID } from 'ee/contextual_sidebar/components/constants';
import TrialStatusWidget from 'ee/contextual_sidebar/components/trial_status_widget.vue';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';

describe('TrialStatusWidget component', () => {
  let wrapper;
  let trackingSpy;

  const { trackingEvents } = WIDGET;
  const trialDaysUsed = 10;
  const trialDuration = 30;

  const findLearnAboutFeaturesBtn = () => wrapper.findByTestId('learn-about-features-btn');

  const createComponent = (providers = {}) => {
    return shallowMountExtended(TrialStatusWidget, {
      provide: {
        trialDaysUsed,
        trialDuration,
        navIconImagePath: 'illustrations/gitlab_logo.svg',
        percentageComplete: 10,
        planName: 'Ultimate',
        trialDiscoverPagePath: 'discover-path',
        ...providers,
      },
      stubs: { GlButton },
    });
  };

  beforeEach(() => {
    useMockLocationHelper();
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('interpolated strings', () => {
    it('correctly interpolates them all', () => {
      wrapper = createComponent();

      expect(wrapper.text()).not.toMatch(/%{\w+}/);
    });
  });

  describe('rendered content', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('matches the snapshot for namespace in active trial', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('matches the snapshot for namespace not in active trial', () => {
      wrapper = createComponent({ percentageComplete: 110 });

      expect(wrapper.element).toMatchSnapshot();
    });

    it('renders with an id', () => {
      expect(wrapper.attributes('id')).toBe(WIDGET_CONTAINER_ID);
    });

    it('does not render Trial twice if the plan name includes "Trial"', () => {
      wrapper = createComponent({ planName: 'Ultimate Trial' });

      expect(wrapper.text()).toMatchInterpolatedText(
        'Ultimate Trial Day 10/30 Learn about features',
      );
    });

    it('shows the expected day 1 text', () => {
      wrapper = createComponent({ trialDaysUsed: 1 });

      expect(wrapper.text()).toMatchInterpolatedText(
        'Ultimate Trial Day 1/30 Learn about features',
      );
    });

    it('shows the expected last day text', () => {
      wrapper = createComponent({ trialDaysUsed: 30 });

      expect(wrapper.text()).toMatchInterpolatedText(
        'Ultimate Trial Day 30/30 Learn about features',
      );
    });
  });

  describe('with link to trial discover page', () => {
    it('renders the link', () => {
      wrapper = createComponent();

      expect(wrapper.text()).toContain('Learn about features');
      expect(findLearnAboutFeaturesBtn().exists()).toBe(true);
      expect(findLearnAboutFeaturesBtn().attributes('href')).toBe('discover-path');
    });

    describe('when trial is active', () => {
      it('tracks clicking learn about features button', async () => {
        wrapper = createComponent();

        const { category } = trackingEvents.activeTrialOptions;
        await findLearnAboutFeaturesBtn().trigger('click');

        expect(trackingSpy).toHaveBeenCalledWith(category, trackingEvents.action, {
          category,
          label: 'learn_about_features',
        });
      });
    });

    describe('when trial is expired', () => {
      it('tracks clicking learn about features link', async () => {
        wrapper = createComponent({ percentageComplete: 110 });

        const { category } = trackingEvents.trialEndedOptions;
        await findLearnAboutFeaturesBtn().trigger('click');

        expect(trackingSpy).toHaveBeenCalledWith(category, trackingEvents.action, {
          category,
          label: 'learn_about_features',
        });
      });
    });
  });
});
