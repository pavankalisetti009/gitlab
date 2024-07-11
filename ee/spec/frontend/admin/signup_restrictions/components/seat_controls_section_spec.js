import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SeatControlsMemberPromotionManagement from 'ee/pages/admin/application_settings/general/components/seat_controls_member_promotion_management.vue';
import SeatControlsSection from 'ee/pages/admin/application_settings/general/components/seat_controls_section.vue';

describe('SeatControlsSection', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSeatControlsMemberPromotionManagement = () =>
    wrapper.findComponent(SeatControlsMemberPromotionManagement);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(SeatControlsSection, {
      provide: {
        ...provide,
      },
    });
  };

  describe('With member promotion management available', () => {
    beforeEach(() => {
      mountComponent({ provide: { promotionManagementAvailable: true } });
    });

    it('will display the SeatControlsMemberPromotionManagement', () => {
      expect(findSeatControlsMemberPromotionManagement().exists()).toBe(true);
    });

    it('will re-emit `form-value-change` events', () => {
      const seatControlsMemberPromotionManagement = findSeatControlsMemberPromotionManagement();
      const payload = { name: 'enableMemberPromotionManagement', value: true };

      seatControlsMemberPromotionManagement.vm.$emit('form-value-change', payload);

      expect(wrapper.emitted('form-value-change')).toEqual([[payload]]);
    });
  });

  describe('With member promotion management unavailable', () => {
    it('will not display SeatControlsMemberPromotionManagement', () => {
      mountComponent({ provide: { promotionManagementAvailable: false } });

      expect(findSeatControlsMemberPromotionManagement().exists()).toBe(false);
    });
  });
});
