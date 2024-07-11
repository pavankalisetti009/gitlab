<script>
import SignupCheckbox from '~/pages/admin/application_settings/general/components/signup_checkbox.vue';

export default {
  name: 'SeatControlsMemberPromotionManagement',
  components: {
    SignupCheckbox,
  },
  inject: ['enableMemberPromotionManagement'],
  data() {
    return {
      form: {
        enableMemberPromotionManagement: this.enableMemberPromotionManagement,
      },
    };
  },
  methods: {
    onInput(value) {
      this.form.enableMemberPromotionManagement = value;
      this.$emit('form-value-change', { name: 'enableMemberPromotionManagement', value });
    },
  },
};
</script>
<template>
  <div>
    <signup-checkbox
      :value="form.enableMemberPromotionManagement"
      name="application_setting[enable_member_promotion_management]"
      :label="s__('ApplicationSettings|Approve role promotions')"
      :help-text="
        s__(
          'ApplicationSettings|Require admin approval when a non-billable user is moving into a billable role.',
        )
      "
      @input="onInput($event)"
    />
  </div>
</template>
