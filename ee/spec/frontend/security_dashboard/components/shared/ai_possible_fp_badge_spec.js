import { GlBadge, GlPopover, GlProgressBar, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  VULNERABILITY_STATE_OBJECTS,
  CONFIDENCE_SCORES,
  AI_FP_DISMISSAL_COMMENT,
} from 'ee/vulnerabilities/constants';
import AiPossibleFpBadge, {
  EXPECTED_STATUS,
  VULNERABILITY_UNTRIAGED_STATUS,
} from 'ee/security_dashboard/components/shared/ai_possible_fp_badge.vue';

describe('AiPossibleFpBadge', () => {
  let wrapper;
  let apolloMutateSpy;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerabilities::Finding/123',
    title: 'Test Vulnerability',
    state: VULNERABILITY_UNTRIAGED_STATUS,
    latestFlag: {
      status: EXPECTED_STATUS,
      confidenceScore: 0.5,
      description: 'This is likely a false positive because...',
    },
  };

  const createComponent = (props = {}, options = {}) => {
    apolloMutateSpy = jest.fn().mockResolvedValue({});

    return shallowMountExtended(AiPossibleFpBadge, {
      propsData: {
        vulnerability: {
          ...defaultVulnerability,
          ...props.vulnerability,
        },
        canAdminVulnerability: false,
        ...props,
      },
      stubs: {
        GlPopover,
      },
      mocks: {
        $apollo: {
          mutate: apolloMutateSpy,
        },
      },
      ...options,
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgeText = () => wrapper.findByTestId('ai-fix-in-progress-b');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findRemoveFlagButton = () => wrapper.findComponent(GlButton);

  describe('when confidence score is between minimal and likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            status: EXPECTED_STATUS,
            confidenceScore: 0.5,
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
      expect(wrapper.text()).toContain('AI Confidence Score');
      expect(findProgressBar().props('value')).toBe(50);
      expect(findProgressBar().props('variant')).toBe('warning');
      expect(wrapper.text()).toContain('50%');
    });
  });

  describe('when confidence score is above the likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            status: EXPECTED_STATUS,
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
      expect(findProgressBar().props('value')).toBe(80);
    });
  });

  describe('when confidence score is below the minimal threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            status: EXPECTED_STATUS,
            confidenceScore: CONFIDENCE_SCORES.MINIMAL - 0.1,
          },
        },
      });
    });

    it('does not render the badge', () => {
      expect(findBadge().exists()).toBe(false);
    });
  });

  describe('when flag description is present', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the description section', () => {
      expect(wrapper.text()).toContain('Why it is likely a false positive');
      expect(wrapper.text()).toContain('This is likely a false positive because...');
    });
  });

  describe('when flag description is not present', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            status: EXPECTED_STATUS,
            confidenceScore: 0.5,
            description: null,
          },
        },
      });
    });

    it('does not render the description section', () => {
      expect(wrapper.text()).not.toContain('Why it is likely a false positive');
    });
  });

  describe('Apollo mutations', () => {
    beforeEach(() => {
      wrapper = createComponent({
        canAdminVulnerability: true,
      });
    });

    it('renders the remove flag button', () => {
      expect(findRemoveFlagButton().exists()).toBe(true);
      expect(findRemoveFlagButton().text()).toBe('Remove False Positive Flag');
    });

    it('calls Apollo mutation with correct parameters when removing flag', async () => {
      await findRemoveFlagButton().vm.$emit('click');

      expect(apolloMutateSpy).toHaveBeenCalledWith({
        mutation: VULNERABILITY_STATE_OBJECTS.dismissed.mutation,
        variables: {
          id: defaultVulnerability.id,
          dismissalReason: 'FALSE_POSITIVE',
          comment: AI_FP_DISMISSAL_COMMENT,
        },
        refetchQueries: [null],
      });
    });
  });

  describe('when user cannot admin vulnerability', () => {
    beforeEach(() => {
      wrapper = createComponent({
        canAdminVulnerability: false,
      });
    });

    it('does not render the remove flag button', () => {
      expect(findRemoveFlagButton().exists()).toBe(false);
    });
  });

  describe('when vulnerability is not untriaged', () => {
    beforeEach(() => {
      wrapper = createComponent({
        canAdminVulnerability: true,
        vulnerability: {
          ...defaultVulnerability,
          state: 'RESOLVED',
        },
      });
    });

    it('does not render the remove flag button', () => {
      expect(findRemoveFlagButton().exists()).toBe(false);
    });
  });
});
