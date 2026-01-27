import { GlProgressBar } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FalsePositiveDetails from 'ee/vulnerabilities/components/false_positive_details.vue';
import DismissFalsePositiveModal from 'ee/security_dashboard/components/shared/dismiss_false_positive_modal.vue';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import { stubComponent } from 'helpers/stub_component';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';

useMockLocationHelper();

describe('FalsePositiveDetails', () => {
  let wrapper;

  const createWrapper = (vulnerabilityOverrides = {}) => {
    const vulnerability = {
      id: 123,
      falsePositive: true,
      canAdmin: true,
      latestFlag: {
        description: 'This is a false positive because...',
        confidenceScore: 0.85,
      },
      ...vulnerabilityOverrides,
    };

    wrapper = mountExtended(FalsePositiveDetails, {
      propsData: { vulnerability },
      stubs: {
        DismissFalsePositiveModal: stubComponent(DismissFalsePositiveModal),
        NonGfmMarkdown: true,
      },
    });
  };

  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findModal = () => wrapper.findComponent(DismissFalsePositiveModal);
  const findConfidenceScore = () => wrapper.findByTestId('false-positive-confidence-score');
  const findResult = () => wrapper.findByTestId('false-positive-result');
  const findRemoveButton = () => wrapper.findByTestId('remove-false-positive-button');
  const findShowMoreButton = () => wrapper.findByTestId('show-all-description-btn');
  const findShowLessButton = () => wrapper.findByTestId('show-less-description-btn');

  describe('confidence score display', () => {
    it('displays the confidence score as a percentage', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.85 } });

      expect(findConfidenceScore().text()).toContain('85%');
    });

    it('displays the progress bar with correct value', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.75 } });

      const progressBar = findProgressBar();
      expect(progressBar.exists()).toBe(true);
      expect(progressBar.props('value')).toBe(75);
    });
  });

  describe('confidence score variant', () => {
    it('shows success variant for confidence score above LIKELY_FALSE_POSITIVE', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.8 } });

      const progressBar = findProgressBar();
      expect(progressBar.props('variant')).toBe('success');
    });

    it('shows warning variant for confidence score between MINIMAL and LIKELY_FALSE_POSITIVE', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.75 } });

      const progressBar = findProgressBar();
      expect(progressBar.props('variant')).toBe('warning');
    });

    it('shows primary variant for confidence score below MINIMAL', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.5 } });

      const progressBar = findProgressBar();
      expect(progressBar.props('variant')).toBe('primary');
    });
  });

  describe('false positive result text', () => {
    it('shows "likely a false positive" when confidence score is high', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.85 } });

      expect(findResult().text()).toContain('likely a false positive');
    });

    it('shows "possibly a false positive" when confidence score is above minimal but below likely', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.7 } });

      expect(findResult().text()).toContain('possibly a false positive');
    });

    it('shows "not a false positive" when confidence score is at or below minimal', () => {
      createWrapper({ latestFlag: { confidenceScore: 0.15 } });

      expect(findResult().text()).toContain('not a false positive');
    });
  });

  describe('description display', () => {
    it('shows description when description exists', () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
        },
      });

      expect(wrapper.findComponent(NonGfmMarkdown).exists()).toBe(true);
      expect(wrapper.findComponent(NonGfmMarkdown).props('markdown')).toBe(
        'This is a false positive because...',
      );
    });

    it('does not show description when description is empty', () => {
      createWrapper({
        latestFlag: {
          description: null,
          confidenceScore: 0.7,
        },
      });

      expect(wrapper.findComponent(NonGfmMarkdown).exists()).toBe(false);
    });
  });

  describe('description truncation', () => {
    it('shows truncated description by default', () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      expect(findShowMoreButton().exists()).toBe(true);
      expect(findShowLessButton().exists()).toBe(false);
    });

    it('expands description when read more button is clicked', async () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      await findShowMoreButton().trigger('click');

      expect(findShowMoreButton().exists()).toBe(false);
      expect(findShowLessButton().exists()).toBe(true);
    });

    it('truncates description when read less button is clicked', async () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      await findShowMoreButton().trigger('click');
      await findShowLessButton().trigger('click');

      expect(findShowMoreButton().exists()).toBe(true);
      expect(findShowLessButton().exists()).toBe(false);
    });
  });

  describe('remove false positive button', () => {
    it('shows remove button when user can admin and falsePositive is true and description is shown', () => {
      createWrapper({
        canAdmin: true,
        falsePositive: true,
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      expect(findRemoveButton().exists()).toBe(true);
      expect(findRemoveButton().text()).toBe('Remove false positive flag');
    });

    it('does not show remove button when user cannot admin', () => {
      createWrapper({
        canAdmin: false,
        falsePositive: true,
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      expect(findRemoveButton().exists()).toBe(false);
    });

    it('shows modal when remove button is clicked', async () => {
      createWrapper({
        canAdmin: true,
        falsePositive: true,
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      const showSpy = jest.spyOn(wrapper.vm.$refs.confirmModal, 'show');

      await findRemoveButton().trigger('click');

      expect(showSpy).toHaveBeenCalled();
    });
  });

  describe('modal', () => {
    it('renders the confirmation modal', () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      expect(findModal().exists()).toBe(true);
    });

    it('reloads page on modal success', async () => {
      createWrapper({
        latestFlag: {
          description: 'This is a false positive because...',
          confidenceScore: 0.7,
        },
      });

      await findModal().vm.$emit('success');

      expect(window.location.reload).toHaveBeenCalled();
    });
  });
});
