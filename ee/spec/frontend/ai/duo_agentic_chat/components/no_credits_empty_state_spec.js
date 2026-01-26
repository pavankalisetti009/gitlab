import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NoCreditsEmptyState from 'ee/ai/duo_agentic_chat/components/no_credits_empty_state.vue';

describe('NoCreditsEmptyState', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(NoCreditsEmptyState, {
      propsData: props,
    });
  };

  const findTurnOffButton = () => wrapper.findComponent(GlButton);
  const findContainer = () => wrapper.findByTestId('no-credits-empty-state');
  const findImage = () => wrapper.find('img');
  const findHeading = () => wrapper.find('h2');
  const findParagraphs = () => wrapper.findAll('p');

  describe('rendering', () => {
    it('renders correctly', () => {
      createComponent({ isClassicAvailable: true });

      expect(findContainer().exists()).toBe(true);
      expect(findImage().exists()).toBe(true);
      expect(findHeading().text()).toBe('No GitLab Credits remain');
      expect(findParagraphs()).toHaveLength(2);
      expect(findTurnOffButton().exists()).toBe(true);
    });
  });

  describe('conditional rendering', () => {
    it('does not render "Turn off Agentic mode" button when isClassicAvailable is false', () => {
      createComponent({ isClassicAvailable: false });

      expect(findTurnOffButton().exists()).toBe(false);
    });

    it('renders "Turn off Agentic mode" button when isClassicAvailable is true', () => {
      createComponent({ isClassicAvailable: true });

      expect(findTurnOffButton().exists()).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent({ isClassicAvailable: true });
    });

    it('emits "return-to-classic" when "Turn off Agentic mode" button is clicked', () => {
      findTurnOffButton().vm.$emit('click');

      expect(wrapper.emitted('return-to-classic')).toHaveLength(1);
    });
  });
});
