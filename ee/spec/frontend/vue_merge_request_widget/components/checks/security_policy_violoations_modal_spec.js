import { GlAlert, GlModal, GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import SecurityPolicyViolationsSelector from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_selector.vue';
import { WARN_MODE, EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';

describe('SecurityPolicyViolationsModal', () => {
  let wrapper;

  const mockPolicies = [
    { value: 'policy-1', text: 'Security Policy 1' },
    { value: 'policy-2', text: 'Security Policy 2' },
    { value: 'policy-3', text: 'Security Policy 3' },
  ];

  const findModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSecurityPolicyViolationsSelector = () =>
    wrapper.findComponent(SecurityPolicyViolationsSelector);
  const findPolicySelector = () => wrapper.findByTestId('policy-selector');
  const findReasonSelector = () => wrapper.findByTestId('reason-selector');
  const findBypassTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findBypassButton = () => wrapper.findByTestId('bypass-policy-violations-button');
  const findModalContent = () => wrapper.findByTestId('modal-content');

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SecurityPolicyViolationsModal, {
      propsData: {
        policies: mockPolicies,
        visible: true,
        mode: WARN_MODE,
        ...props,
      },
      stubs: {
        GlModal,
      },
    });
  };

  const fillFormWithData = async () => {
    await findPolicySelector().vm.$emit('select', ['policy-1']);
    await findReasonSelector().vm.$emit('select', ['policy_false_positive']);
    await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');
  };

  describe('modal structure', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findSecurityPolicyViolationsSelector().exists()).toBe(false);
      expect(findModalContent().exists()).toBe(true);
    });

    it('renders policy selector with correct props', () => {
      const selector = findPolicySelector();
      expect(selector.props('items')).toEqual(mockPolicies);
      expect(selector.props('multiple')).toBe(true);
    });

    it('renders reason selector with bypass reasons', () => {
      expect(findReasonSelector().props('items')).toEqual([
        { value: 'policy_false_positive', text: 'Policy false positive' },
        { value: 'scanner_false_positive', text: 'Scanner false positive' },
        { value: 'emergency_hotfix', text: 'Emergency hotfix' },
        { value: 'other', text: 'Other' },
      ]);
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('disables bypass button when form is invalid', () => {
      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('enables bypass button when all fields are filled', async () => {
      await fillFormWithData();

      expect(findBypassButton().attributes().disabled).toBeUndefined();
    });

    it('disables bypass button when policies are not selected', async () => {
      await findReasonSelector().vm.$emit('input', ['policy_false_positive']);
      await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when reasons are not selected', async () => {
      await findPolicySelector().vm.$emit('input', ['policy-1']);
      await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when bypass reason is empty', async () => {
      await findPolicySelector().vm.$emit('input', ['policy-1']);
      await findReasonSelector().vm.$emit('input', ['policy_false_positive']);

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when bypass reason is only whitespace', async () => {
      await findPolicySelector().vm.$emit('input', ['policy-1']);
      await findReasonSelector().vm.$emit('input', ['policy_false_positive']);
      await findBypassTextarea().vm.$emit('input', '   ');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });
  });

  describe('toggle text computation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows placeholder text when no policies are selected', () => {
      expect(findPolicySelector().props('toggleText')).toBe('Select policies');
    });

    it('shows placeholder text when no reasons are selected', () => {
      expect(findReasonSelector().props('toggleText')).toBe('Select bypass reasons');
    });

    it('updates toggle text when policies are selected', async () => {
      await findPolicySelector().vm.$emit('select', ['policy-1']);

      expect(findPolicySelector().props('toggleText')).toContain('Security Policy 1');
    });

    it('updates toggle text when reasons are selected', async () => {
      await findReasonSelector().vm.$emit('select', ['policy_false_positive']);

      expect(findReasonSelector().props('toggleText')).toContain('Policy false positive');
    });
  });

  describe('modal actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits close event when cancel button is clicked', async () => {
      await findModal().vm.$emit('cancel');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('emits close event when modal is closed via change event', async () => {
      await findModal().vm.$emit('change');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('calls handleBypass and emits close when primary button is clicked', async () => {
      await fillFormWithData();
      await findModal().vm.$emit('primary');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('visibility prop', () => {
    it('passes visible prop to modal', () => {
      createComponent();
      expect(findModal().props('visible')).toBe(true);

      createComponent({ visible: false });
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('mode selection', () => {
    beforeEach(() => {
      createComponent({
        mode: '',
      });
    });

    it('renders mode selector', () => {
      expect(findAlert().text()).toContain(
        'You have permissions to bypass all checks in this merge request or selectively only bypass Warn Mode policies.',
      );
      expect(findAlert().text()).toContain(
        'Choose from the options below based on how you would like to proceed.',
      );

      expect(findSecurityPolicyViolationsSelector().exists()).toBe(true);
      expect(findModalContent().exists()).toBe(false);
    });

    it.each([WARN_MODE, EXCEPTION_MODE])('emits select mode events', (mode) => {
      findSecurityPolicyViolationsSelector().vm.$emit('select', mode);

      expect(wrapper.emitted('select-mode')).toEqual([[mode]]);
    });
  });

  describe('exception mode', () => {
    it('renders correct alert message and reasons for exception mode', () => {
      createComponent({
        mode: EXCEPTION_MODE,
      });

      expect(findAlert().text()).toContain('All selected policy requirements will be bypassed.');
      expect(findAlert().text()).toContain('The action will be logged in the audit log.');

      expect(findReasonSelector().props('items')).toEqual([
        { text: 'Emergency production issue', value: 'emergency' },
        { text: 'Critical business deadline', value: 'critical' },
        { text: 'Technical limitation', value: 'technical' },
        {
          text: 'Authorized business risk acceptance',
          value: 'authorized_risk',
        },
        { text: 'Other', value: 'other' },
      ]);
    });
  });
});
