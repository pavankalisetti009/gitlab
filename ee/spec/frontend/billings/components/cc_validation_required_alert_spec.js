import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AccountVerificationModal from 'ee/billings/components/account_verification_modal.vue';
import CreditCardValidationRequiredAlert from 'ee/billings/components/cc_validation_required_alert.vue';
import { TEST_HOST } from 'helpers/test_constants';

describe('CreditCardValidationRequiredAlert', () => {
  let wrapper;

  const createComponent = ({ data = {}, props = {} } = {}) => {
    return shallowMount(CreditCardValidationRequiredAlert, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
      data() {
        return data;
      },
    });
  };

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findAccountVerificationModal = () => wrapper.findComponent(AccountVerificationModal);

  beforeEach(() => {
    window.gon = {
      subscriptions_url: TEST_HOST,
      payment_form_url: TEST_HOST,
    };

    wrapper = createComponent();
  });

  it('renders title', () => {
    expect(findGlAlert().attributes('title')).toBe('User validation required');
  });

  it('renders description', () => {
    expect(findGlAlert().text()).toContain('To use free compute minutes');
  });

  it('renders danger alert', () => {
    expect(findGlAlert().attributes('variant')).toBe('danger');
  });

  it('renders the success alert instead of danger', () => {
    wrapper = createComponent({ data: { shouldRenderSuccess: true } });

    expect(findGlAlert().attributes('variant')).toBe('success');
  });

  it('hides the modal and emits a verifiedCreditCard event upon success', () => {
    const accountVerificationModal = findAccountVerificationModal();
    accountVerificationModal.vm.$emit('success');

    expect(accountVerificationModal.props('visible')).toBe(false);
    expect(wrapper.emitted('verifiedCreditCard')).toBeDefined();
  });

  it('danger alert emits dismiss event on dismiss', () => {
    findGlAlert().vm.$emit('dismiss');

    expect(wrapper.emitted('dismiss')).toBeDefined();
  });

  it('does not open the modal on mount', () => {
    expect(findAccountVerificationModal().props('visible')).toBe(false);
  });
});
