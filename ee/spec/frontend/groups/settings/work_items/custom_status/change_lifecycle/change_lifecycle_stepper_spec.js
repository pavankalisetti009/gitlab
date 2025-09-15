import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ChangeLifecycleStepper from 'ee/groups/settings/work_items/custom_status/change_lifecycle/change_lifecycle_stepper.vue';

describe('ChangeLifecycleStepper', () => {
  let wrapper;

  const mockSteps = [
    { label: 'Step 1', description: 'First step' },
    { label: 'Step 2', description: 'Second step' },
    { label: 'Step 3', description: 'Third step' },
  ];

  const defaultProps = {
    steps: mockSteps,
  };

  // Finder methods
  const findStepItems = () => wrapper.findAll('.workflow-step');
  const findActiveStep = () => wrapper.find('.workflow-step.active');
  const findCompletedSteps = () => wrapper.findAll('.workflow-step.completed');
  const findDisabledSteps = () => wrapper.findAll('.workflow-step.disabled');
  const findStepContent = () => wrapper.findByTestId('step-content');
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findBackButton = () => wrapper.findByTestId('stepper-back');
  const findNextButton = () => wrapper.findByTestId('stepper-next');
  const findFinishButton = () => wrapper.findByTestId('stepper-finish');
  const findCancelButton = () => wrapper.findByTestId('stepper-cancel');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ChangeLifecycleStepper, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlButton,
      },
    });
  };

  describe('Component Rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders all steps with correct labels', () => {
      expect(findStepItems()).toHaveLength(3);

      findStepItems().wrappers.forEach((step, index) => {
        expect(step.find('[data-testid="step-header"]').text()).toBe(mockSteps[index].label);
      });
    });

    it('renders first step as active by default', () => {
      expect(findActiveStep().exists()).toBe(true);
      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 1');
    });

    it('renders step content for active step', () => {
      expect(findStepContent().exists()).toBe(true);
    });

    it('shows cancel button by default', () => {
      expect(findCancelButton().text()).toBe('Cancel');
    });
  });

  describe('Initial Step', () => {
    it('starts at specified initial step', () => {
      createWrapper({ initialStep: 1 });

      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 2');
    });

    it('shows completed steps before initial step', () => {
      createWrapper({ initialStep: 2 });

      expect(findCompletedSteps()).toHaveLength(2);
      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 3');
    });
  });

  describe('Step Navigation', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not show back button on first step', () => {
      expect(findBackButton().exists()).toBe(false);
    });

    it('shows next button when not on last step', () => {
      expect(findNextButton().exists()).toBe(true);
      expect(findNextButton().text()).toBe('Next');
    });

    it('does not show finish button when not on last step', () => {
      expect(findFinishButton().exists()).toBe(false);
    });

    it('progresses to next step when next button clicked', async () => {
      await findNextButton().vm.$emit('click');

      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 2');
      expect(findCompletedSteps()).toHaveLength(1);
    });

    it('shows back button after progressing', async () => {
      await findNextButton().vm.$emit('click');

      expect(findBackButton().exists()).toBe(true);
      expect(findBackButton().text()).toBe('Back');
    });

    it('goes back to previous step when back button clicked', async () => {
      await findNextButton().vm.$emit('click');
      await findBackButton().vm.$emit('click');

      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 1');
      expect(findCompletedSteps()).toHaveLength(0);
    });
  });

  describe('Final Step', () => {
    beforeEach(() => {
      createWrapper({ initialStep: 2 });
    });

    it('shows finish button on last step', () => {
      expect(findFinishButton().text()).toBe('Finish');
    });

    it('does not show next button on last step', () => {
      expect(findNextButton().exists()).toBe(false);
    });

    it('shows back button on last step', () => {
      expect(findBackButton().exists()).toBe(true);
    });
  });

  describe('Button Visibility Props', () => {
    it('hides actions when showActions is false', () => {
      createWrapper({ showActions: false });

      expect(findButtons()).toHaveLength(0);
    });

    it('hides back button when showBackButton is false', () => {
      createWrapper({ initialStep: 1, showBackButton: false });

      expect(findBackButton().exists()).toBe(false);
    });

    it('hides next button when showNextButton is false', () => {
      createWrapper({ showNextButton: false });

      expect(findNextButton().exists()).toBe(false);
    });

    it('hides finish button when showFinishButton is false', () => {
      createWrapper({ initialStep: 2, showFinishButton: false });

      expect(findFinishButton().exists()).toBe(false);
    });

    it('hides cancel button when showCancelButton is false', () => {
      createWrapper({ showCancelButton: false });

      expect(findCancelButton().exists()).toBe(false);
    });
  });

  describe('Allow Skip', () => {
    it('disables future steps when allowSkip is false', () => {
      createWrapper({ allowSkip: false });

      expect(findDisabledSteps()).toHaveLength(2);
    });

    it('does not disable future steps when allowSkip is true', () => {
      createWrapper({ allowSkip: true });

      expect(findDisabledSteps()).toHaveLength(0);
    });
  });

  describe('Events', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits step-change event when progressing forward', async () => {
      await findNextButton().vm.$emit('click');

      expect(wrapper.emitted('step-change')).toHaveLength(1);
      expect(wrapper.emitted('step-change')[0][0]).toMatchObject({
        currentStep: 1,
        direction: 'next',
        step: mockSteps[1],
      });
    });

    it('emits step-change event when going backward', async () => {
      await findNextButton().vm.$emit('click');
      await findBackButton().vm.$emit('click');

      expect(wrapper.emitted('step-change')).toHaveLength(2);
      expect(wrapper.emitted('step-change')[1][0]).toMatchObject({
        currentStep: 0,
        direction: 'previous',
        step: mockSteps[0],
      });
    });

    it('emits validate-step event before progressing', async () => {
      await findNextButton().vm.$emit('click');

      expect(wrapper.emitted('validate-step')).toHaveLength(1);
      expect(wrapper.emitted('validate-step')[0][0]).toMatchObject({
        stepIndex: 0,
        step: mockSteps[0],
      });
    });

    it('emits finish event when finish button clicked', async () => {
      createWrapper({ initialStep: 2 });

      await findFinishButton().vm.$emit('click');

      expect(wrapper.emitted('finish')).toHaveLength(1);
      expect(wrapper.emitted('finish')[0][0]).toMatchObject({
        completedSteps: mockSteps,
        currentStep: 2,
      });
    });

    it('emits cancel event when cancel button clicked', async () => {
      await findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('Slots', () => {
    it('renders default content when no slot provided', () => {
      createWrapper();

      const defaultContent = wrapper.find('.default-content');
      expect(defaultContent.exists()).toBe(true);
      expect(defaultContent.find('h2').text()).toBe('Step 1');
      expect(defaultContent.find('p').text()).toBe('First step');
    });
  });
});
