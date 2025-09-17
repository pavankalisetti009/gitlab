import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RiskScoreTooltip from 'ee/security_dashboard/components/shared/risk_score_tooltip.vue';

describe('RiskScoreTooltip', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    vulnerabilitiesAverageScoreFactor: 2.5,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RiskScoreTooltip, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDescription = () => wrapper.findByTestId('risk-score-description');
  const findLabelForId = (id) => wrapper.findByTestId(`${id}-label`);
  const findValueForId = (id) => wrapper.findByTestId(`${id}-value`);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('loaded state', () => {
    beforeEach(createComponent);

    it('renders the vulnerabilities average score label', () => {
      expect(findLabelForId('vulnerabilities-average-score').text()).toBe(
        'Vulnerabilities average score',
      );
    });

    it('displays the formatted score value', () => {
      expect(findValueForId('vulnerabilities-average-score').text()).toBe(
        `${defaultProps.vulnerabilitiesAverageScoreFactor}x`,
      );
    });

    it('renders the description text', () => {
      expect(findDescription().text()).toBe(
        '(Includes Severity, Age, Exploitation status, EPSS score, Reachability, and/or Secret validity)',
      );
    });

    it('does not show skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('shows skeleton loader when loading', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('still shows the label when loading', () => {
      expect(findLabelForId('vulnerabilities-average-score').text()).toBe(
        'Vulnerabilities average score',
      );
    });

    it('still shows the description when loading', () => {
      expect(findDescription().exists()).toBe(true);
    });
  });
});
