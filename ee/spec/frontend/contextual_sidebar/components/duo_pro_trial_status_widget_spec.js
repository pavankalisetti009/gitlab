import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoProTrialStatusWidget from 'ee/contextual_sidebar/components/duo_pro_trial_status_widget.vue';
import { WIDGET_CONTAINER_ID } from 'ee/contextual_sidebar/components/constants';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';

describe('DuoProTrialStatusWidget component', () => {
  let wrapper;
  let trackingSpy;

  const trialDaysUsed = 10;
  const trialDuration = 60;

  const findRootElement = () => wrapper.findByTestId('duo-pro-trial-widget-root-element');
  const findDismissBtn = () => wrapper.findByTestId('dismiss-btn');
  const findLearnAboutFeaturesBtn = () => wrapper.findByTestId('learn-about-features-btn');

  const createComponent = (providers = {}) => {
    return shallowMountExtended(DuoProTrialStatusWidget, {
      provide: {
        trialDaysUsed,
        trialDuration,
        percentageComplete: 10,
        groupId: 1,
        featureId: 'expired_duo_pro_trial_widget',
        dismissEndpoint: 'some/dismiss/endpoint',
        learnAboutButtonUrl: 'learn-path',
        ...providers,
      },
      stubs: { GlButton },
    });
  };

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

    it('renders with an id', () => {
      expect(findRootElement().attributes('id')).toBe(WIDGET_CONTAINER_ID);
    });

    it('shows the expected day 1 text', () => {
      wrapper = createComponent({ trialDaysUsed: 1 });

      expect(wrapper.text()).toMatchInterpolatedText('GitLab Duo Pro Trial Day 1/60');
    });

    it('shows the expected last day text', () => {
      wrapper = createComponent({ trialDaysUsed: 60 });

      expect(wrapper.text()).toMatchInterpolatedText('GitLab Duo Pro Trial Day 60/60');
    });

    it('does not render the dismiss button', () => {
      wrapper = createComponent();

      expect(findDismissBtn().exists()).toBe(false);
    });

    describe('dismissible class', () => {
      it('adds the class', () => {
        expect(findRootElement().attributes('class')).toContain('js-expired-duo-pro-trial-widget');
      });

      describe('when groupId is empty', () => {
        it('does not add the class', () => {
          wrapper = createComponent({ groupId: null });

          expect(findRootElement().attributes('class')).not.toContain(
            'js-expired-duo-pro-trial-widget',
          );
        });
      });

      describe('when featureId is empty', () => {
        it('does not add the class', () => {
          wrapper = createComponent({ featureId: null });

          expect(findRootElement().attributes('class')).not.toContain(
            'js-expired-duo-pro-trial-widget',
          );
        });
      });

      describe('when dismissEndpoint is empty', () => {
        it('does not add the class', () => {
          wrapper = createComponent({ dismissEndpoint: null });

          expect(findRootElement().attributes('class')).not.toContain(
            'js-expired-duo-pro-trial-widget',
          );
        });
      });
    });

    describe('when an expired trial', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
        wrapper = createComponent({ percentageComplete: 110 });
      });

      afterEach(() => {
        unmockTracking();
      });

      it('shows correct title and body', () => {
        expect(wrapper.text()).toMatchInterpolatedText(
          'Your 60-day trial has ended Looking to do more with AI? Learn about GitLab Duo',
        );
      });

      it('renders the dismiss button', () => {
        expect(findDismissBtn().exists()).toBe(true);
      });

      it('tracks clicking learn about features link', async () => {
        const category = 'duo_pro_expired_trial';
        const action = 'click_link';

        await findLearnAboutFeaturesBtn().trigger('click');

        expect(trackingSpy).toHaveBeenCalledWith(category, action, {
          category,
          label: 'learn_about_features',
        });
      });
    });
  });
});
