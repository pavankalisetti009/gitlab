import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlModal, GlFormTextarea } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SecurityPolicyViolationsModal from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_modal.vue';
import SecurityPolicyViolationsSelector from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_selector.vue';
import bypassSecurityPolicyViolations from 'ee/vue_merge_request_widget/components/checks/queries/bypass_security_policy_violations.mutation.graphql';
import { WARN_MODE, EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';

Vue.use(VueApollo);
const mockBypassSecurityPolicyViolationsResponses = {
  success: jest.fn().mockResolvedValue({
    data: {
      dismissPolicyViolations: {
        errors: [],
        typename: '__DismissPolicyViolationsPayload',
      },
    },
  }),
  successWithErrors: jest.fn().mockResolvedValue({
    data: {
      dismissPolicyViolations: {
        errors: ['no policies'],
        typename: '__DismissPolicyViolationsPayload',
      },
    },
  }),
  failure: jest.fn().mockRejectedValue(),
};

describe('SecurityPolicyViolationsModal', () => {
  let wrapper;

  const mockPolicies = [
    { value: 'policy-1', text: 'Security Policy 1', id: 1 },
    { value: 'policy-2', text: 'Security Policy 2', id: 2 },
    { value: 'policy-3', text: 'Security Policy 3', id: 3 },
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

  const createComponent = ({
    mutationQuery = bypassSecurityPolicyViolations,
    mutationResult = mockBypassSecurityPolicyViolationsResponses.success,
    props = {},
  } = {}) => {
    wrapper = shallowMountExtended(SecurityPolicyViolationsModal, {
      apolloProvider: createMockApollo([[mutationQuery, mutationResult]]),
      propsData: {
        policies: mockPolicies,
        visible: true,
        mode: WARN_MODE,
        mr: {
          iid: 123,
          targetProjectFullPath: 'test/project',
        },
        ...props,
      },
      stubs: {
        GlModal,
      },
    });
  };

  const fillFormWithData = async () => {
    await findPolicySelector().vm.$emit('select', [1]);
    await findReasonSelector().vm.$emit('select', ['POLICY_FALSE_POSITIVE']);
    await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');
  };

  describe('modal structure', () => {
    beforeEach(() => {
      createComponent({});
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
        { value: 'POLICY_FALSE_POSITIVE', text: 'Policy false positive' },
        { value: 'SCANNER_FALSE_POSITIVE', text: 'Scanner false positive' },
        { value: 'EMERGENCY_HOT_FIX', text: 'Emergency hotfix' },
        { value: 'OTHER', text: 'Other' },
      ]);
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent({});
    });

    it('disables bypass button when form is invalid', () => {
      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('enables bypass button when all fields are filled', async () => {
      await fillFormWithData();

      expect(findBypassButton().attributes().disabled).toBeUndefined();
    });

    it('disables bypass button when policies are not selected', async () => {
      await findReasonSelector().vm.$emit('select', ['POLICY_FALSE_POSITIVE']);
      await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when reasons are not selected', async () => {
      await findPolicySelector().vm.$emit('select', [1]);
      await findBypassTextarea().vm.$emit('input', 'Valid bypass reason');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when bypass reason is empty', async () => {
      await findPolicySelector().vm.$emit('select', [1]);
      await findReasonSelector().vm.$emit('select', ['POLICY_FALSE_POSITIVE']);

      expect(findBypassButton().attributes().disabled).toBe('true');
    });

    it('disables bypass button when bypass reason is only whitespace', async () => {
      await findPolicySelector().vm.$emit('select', [1]);
      await findReasonSelector().vm.$emit('select', ['POLICY_FALSE_POSITIVE']);
      await findBypassTextarea().vm.$emit('input', '   ');

      expect(findBypassButton().attributes().disabled).toBe('true');
    });
  });

  describe('toggle text computation', () => {
    beforeEach(() => {
      createComponent({});
    });

    it('shows placeholder text when no policies are selected', () => {
      expect(findPolicySelector().props('toggleText')).toBe('Select policies');
    });

    it('shows placeholder text when no reasons are selected', () => {
      expect(findReasonSelector().props('toggleText')).toBe('Select bypass reasons');
    });

    it('updates toggle text when policies are selected', async () => {
      await findPolicySelector().vm.$emit('select', [1]);
      expect(findPolicySelector().props('toggleText')).toBe('Security Policy 1');
    });

    it('updates toggle text when reasons are selected', async () => {
      await findReasonSelector().vm.$emit('select', ['POLICY_FALSE_POSITIVE']);

      expect(findReasonSelector().props('toggleText')).toContain('Policy false positive');
    });
  });

  describe('modal events', () => {
    describe('close', () => {
      it('emits close event when cancel button is clicked', async () => {
        createComponent({});
        await findModal().vm.$emit('cancel');

        expect(wrapper.emitted('close')).toHaveLength(1);
      });
    });

    describe('primary', () => {
      it('closes the modal when `bypassSecurityPolicyViolations` query is successful', async () => {
        createComponent({});
        await fillFormWithData();
        await findModal().vm.$emit('primary', { preventDefault: jest.fn() });
        expect(mockBypassSecurityPolicyViolationsResponses.success).toHaveBeenCalled();
        await waitForPromises();
        expect(wrapper.emitted('close')).toEqual([[]]);
      });

      it('does not close the modal when `bypassSecurityPolicyViolations` query fails with errors', async () => {
        createComponent({
          mutationResult: mockBypassSecurityPolicyViolationsResponses.successWithErrors,
        });
        await fillFormWithData();
        await findModal().vm.$emit('primary', { preventDefault: jest.fn() });
        expect(mockBypassSecurityPolicyViolationsResponses.successWithErrors).toHaveBeenCalled();
        await waitForPromises();
        expect(wrapper.emitted('close')).toBe(undefined);
      });

      it('does not close the modal when `bypassSecurityPolicyViolations` query fails', async () => {
        createComponent({ mutationResult: mockBypassSecurityPolicyViolationsResponses.failure });
        await fillFormWithData();
        await findModal().vm.$emit('primary', { preventDefault: jest.fn() });
        expect(mockBypassSecurityPolicyViolationsResponses.failure).toHaveBeenCalled();
        await waitForPromises();
        expect(wrapper.emitted('close')).toBe(undefined);
      });
    });
  });

  describe('visibility prop', () => {
    it('passes visible prop to modal', () => {
      createComponent({ props: { visible: true } });
      expect(findModal().props('visible')).toBe(true);
    });
  });

  describe('mode selection', () => {
    beforeEach(() => {
      createComponent({ props: { mode: '' } });
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
      createComponent({ props: { mode: EXCEPTION_MODE } });

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
