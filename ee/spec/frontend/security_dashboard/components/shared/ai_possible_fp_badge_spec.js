import { GlBadge, GlPopover, GlProgressBar, GlButton } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { CONFIDENCE_SCORES } from 'ee/vulnerabilities/constants';
import AiPossibleFpBadge, {
  VULNERABILITY_UNTRIAGED_STATUS,
} from 'ee/security_dashboard/components/shared/ai_possible_fp_badge.vue';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import DismissFalsePositiveModal from 'ee/security_dashboard/components/shared/dismiss_false_positive_modal.vue';

describe('AiPossibleFpBadge', () => {
  let wrapper;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerabilities::Finding/123',
    title: 'Test Vulnerability',
    state: VULNERABILITY_UNTRIAGED_STATUS,
    latestFlag: {
      confidenceScore: 0.5,
      description: 'This is likely a false positive because...',
    },
  };

  const modalShowStub = jest.fn();
  const modalStub = { show: modalShowStub };
  const showToastStub = jest.fn();
  const DismissFalsePositiveModalStub = stubComponent(DismissFalsePositiveModal, {
    methods: modalStub,
  });

  const createComponent = (props = {}, options = {}) => {
    wrapper = shallowMountExtended(AiPossibleFpBadge, {
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
        NonGfmMarkdown,
        DismissFalsePositiveModal: DismissFalsePositiveModalStub,
      },
      mocks: {
        $toast: {
          show: showToastStub,
        },
      },
      ...options,
    });
    return wrapper;
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgeText = () => wrapper.findByTestId('ai-fix-in-progress-b');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findRemoveFlagButton = () => wrapper.findComponent(GlPopover).findComponent(GlButton);
  const findModal = () => wrapper.findComponent(DismissFalsePositiveModal);

  describe('when confidence score is between minimal and likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
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
      expect(wrapper.findComponent(NonGfmMarkdown).props('markdown')).toBe(
        'This is likely a false positive because...',
      );
    });
  });

  describe('when flag description is not present', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0.5,
            description: null,
          },
        },
      });
    });

    it('does not render the description section', () => {
      expect(wrapper.text()).not.toContain('Why it is likely a false positive');
      expect(wrapper.findComponent(NonGfmMarkdown).exists()).toBe(false);
    });
  });

  describe('Apollo mutations and modal', () => {
    beforeEach(() => {
      wrapper = createComponent({
        canAdminVulnerability: true,
      });
    });

    it('renders the remove flag button', () => {
      expect(findRemoveFlagButton().exists()).toBe(true);
      expect(findRemoveFlagButton().text()).toBe('Remove False Positive Flag');
    });

    it('renders the confirmation modal', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('vulnerability')).toEqual(defaultVulnerability);
      expect(findModal().props('modalId')).toBe('dismiss-fp-confirm-modal');
    });

    it('shows modal when remove flag button is clicked', async () => {
      await findRemoveFlagButton().vm.$emit('click');
      expect(modalShowStub).toHaveBeenCalled();
    });

    it('handles modal success event and shows toast', async () => {
      const showToastSpy = jest.fn();
      wrapper = createComponent(
        { canAdminVulnerability: true },
        {
          mocks: {
            $toast: {
              show: showToastSpy,
            },
          },
        },
      );

      await findModal().vm.$emit('success');

      expect(showToastSpy).toHaveBeenCalledWith('False positive flag dismissed successfully.');
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
