<script>
import { GlFormGroup } from '@gitlab/ui';
import SeatControlsMemberPromotionManagement from './seat_controls_member_promotion_management.vue';

export default {
  name: 'SeatControlsSection',
  components: {
    GlFormGroup,
    SeatControlsMemberPromotionManagement,
  },
  inject: ['promotionManagementAvailable'],
};
</script>
<template>
  <gl-form-group
    v-if="promotionManagementAvailable"
    :label="s__('ApplicationSettings|Seat controls')"
  >
    <seat-controls-member-promotion-management
      @form-value-change="$emit('form-value-change', $event)"
    />
  </gl-form-group>
</template>
