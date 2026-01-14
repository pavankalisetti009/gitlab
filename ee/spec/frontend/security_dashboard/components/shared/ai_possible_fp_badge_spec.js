import { GlBadge, GlPopover, GlProgressBar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { CONFIDENCE_SCORES } from 'ee/vulnerabilities/constants';
import AiPossibleFpBadge from 'ee/security_dashboard/components/shared/ai_possible_fp_badge.vue';

describe('AiPossibleFpBadge', () => {
  let wrapper;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerabilities::Finding/123',
    title: 'Test Vulnerability',
    latestFlag: {
      confidenceScore: 0.61,
      description: 'This is likely a false positive because...',
    },
  };

  const createComponent = (props = {}, options = {}) => {
    wrapper = shallowMountExtended(AiPossibleFpBadge, {
      propsData: {
        vulnerability: {
          ...defaultVulnerability,
          ...props.vulnerability,
        },
        ...props,
      },
      stubs: {
        GlPopover,
      },
      ...options,
    });
    return wrapper;
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgeText = () => wrapper.findByTestId('ai-fix-in-progress-b');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);

  describe('when confidence score is between minimal and likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0.61,
          },
        },
      });
    });

    it('renders the badge with warning variant', () => {
      expect(findBadge().props('variant')).toBe('warning');
    });

    it('renders "Possible FP" text', () => {
      expect(findBadgeText().text()).toBe('Possible FP');
    });

    it('renders the confidence score correctly', () => {
      expect(findProgressBar().props('value')).toBe(61);
      expect(findProgressBar().props('variant')).toBe('warning');
      expect(wrapper.text()).toContain('61%');
    });
  });

  describe('when confidence score is above the likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE + 0.1,
          },
        },
      });
    });

    it('renders the badge with success variant', () => {
      expect(findBadge().props('variant')).toBe('success');
    });

    it('renders "Likely FP" text', () => {
      expect(findBadgeText().text()).toBe('Likely FP');
    });

    it('renders the progress bar with success variant', () => {
      expect(findProgressBar().props('variant')).toBe('success');
      expect(findProgressBar().props('value')).toBe(90);
    });
  });

  describe('when confidence score is below the minimal threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: CONFIDENCE_SCORES.MINIMAL - 0.1,
          },
        },
      });
    });

    it('renders the badge with neutral variant', () => {
      expect(findBadge().props('variant')).toBe('neutral');
    });

    it('renders "Not an FP" text', () => {
      expect(findBadgeText().text()).toBe('Not an FP');
    });

    it('renders the progress bar with primary variant', () => {
      expect(findProgressBar().props('variant')).toBe('primary');
    });

    it('renders the "Not a false positive" message', () => {
      expect(wrapper.text()).toContain('FP scanning found that this vulnerability is');
      expect(wrapper.text()).toContain('NOT a false positive');
    });
  });

  describe('when confidence score indicates possible or likely false positive', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the "For more information" message', () => {
      expect(wrapper.text()).toContain('For more information, view vulnerability details.');
    });
  });
});
