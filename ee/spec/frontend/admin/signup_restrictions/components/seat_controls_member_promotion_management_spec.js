import { GlAlert } from '@gitlab/ui';
import SeatControlsMemberPromotionManagement from 'ee/pages/admin/application_settings/general/components/seat_controls_member_promotion_management.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SignupCheckbox from '~/pages/admin/application_settings/general/components/signup_checkbox.vue';

describe('SeatControlsMemberPromotionManagement', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSignupCheckbox = () => wrapper.findComponent(SignupCheckbox);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(SeatControlsMemberPromotionManagement, {
      provide: {
        enableMemberPromotionManagement: true,
        canDisableMemberPromotionManagement: false,
        rolePromotionRequestsPath: '/admin/role_promotion',

        ...provide,
      },
    });
  };

  it('will pass the prop to the SignupCheckbox', () => {
    mountComponent();

    expect(findSignupCheckbox().props('value')).toBe(true);
  });

  it('will re-emit value changes from SignupCheckbox', () => {
    mountComponent();

    findSignupCheckbox().vm.$emit('input', false);
    findSignupCheckbox().vm.$emit('input', true);

    expect(wrapper.emitted('form-value-change')).toEqual([
      [{ name: 'enableMemberPromotionManagement', value: false }],
      [{ name: 'enableMemberPromotionManagement', value: true }],
    ]);
  });

  describe('prevent disabling setting', () => {
    it.each`
      canDisableMemberPromotionManagement | alertShown
      ${false}                            | ${true}
      ${true}                             | ${false}
    `(
      'ensures alert existence is related with canDisableMemberPromotionManagement value',
      ({ canDisableMemberPromotionManagement, alertShown }) => {
        mountComponent({
          provide: {
            canDisableMemberPromotionManagement,
          },
        });

        const findAlert = () => wrapper.findComponent(GlAlert);

        expect(findAlert().exists()).toBe(alertShown);
      },
    );
  });
});
