<script>
import { GlFormGroup, GlFormRadio, GlFormRadioGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import SeatControlsMemberPromotionManagement from 'ee_component/pages/admin/application_settings/general/components/seat_controls_member_promotion_management.vue';

const OFF = 0;
const USER_CAP = 1;

const SEAT_CONTROL = Object.freeze({
  OFF,
  USER_CAP,
});

export default {
  name: 'SeatControlsSection',
  components: {
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormInput,
    GlSprintf,
    HelpPageLink,
    SeatControlsMemberPromotionManagement,
  },
  inject: ['licensedUserCount', 'promotionManagementAvailable'],
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      form: {
        ...this.value,
      },
    };
  },
  computed: {
    isUserCapDisabled() {
      return parseInt(this.form.seatControl, 10) !== SEAT_CONTROL.USER_CAP;
    },
  },
  methods: {
    handleSeatControlChange(seatControl) {
      this.form.userCap = seatControl !== SEAT_CONTROL.USER_CAP ? '' : this.form.userCap;
      this.$emit('input', { ...this.form, userCap: this.form.userCap, seatControl });
    },
    handleUserCapChange(userCap) {
      this.$emit('input', { ...this.form, userCap });
    },
  },
  i18n: {
    seatControlsLabel: s__('ApplicationSettings|Seat controls'),
    restrictedAccessLabel: s__('ApplicationSettings|Restricted access'),
    restrictedHelpText: s__('ApplicationSettings|Invitations above seat count are blocked'),
    userCapLabel: s__('ApplicationSettings|Set user cap'),
    userCapHelpText: s__(
      'ApplicationSettings|By setting a user cap, any user who is added or requests access in excess of the user cap must be approved by an admin',
    ),
    openAccessLabel: s__('ApplicationSettings|Open access'),
    openAccessHelpText: s__(
      'ApplicationSettings|Invitations do not require administrator approval',
    ),
  },
  SEAT_CONTROL,
};
</script>

<template>
  <div>
    <gl-form-group :label="s__('ApplicationSettings|Seat controls')" label-for="seat-controls">
      <gl-form-radio-group
        v-model="form.seatControl"
        name="application_setting[seat_control]"
        @change="handleSeatControlChange"
      >
        <gl-form-radio :value="$options.SEAT_CONTROL.USER_CAP" data-testid="seat-controls-user-cap">
          {{ s__('ApplicationSettings|Set user cap') }}
          <template #help>{{
            s__(
              'ApplicationSettings|By setting a user cap, any user who is added or requests access in excess of the user cap must be approved by an admin',
            )
          }}</template>
        </gl-form-radio>

        <div class="gl-ml-6 gl-mt-3">
          <gl-form-group data-testid="user-cap-group">
            <gl-form-input
              v-model="form.userCap"
              type="text"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input"
              :disabled="isUserCapDisabled"
              @change="handleUserCapChange"
            />
            <input
              type="hidden"
              name="application_setting[new_user_signups_cap]"
              :disabled="!isUserCapDisabled"
              :value="form.userCap"
            />
            <small class="form-text text-muted">
              {{
                s__(
                  'ApplicationSettings|Users added beyond this limit require administrator approval. Leave blank for unlimited.',
                )
              }}
              <gl-sprintf
                v-if="licensedUserCount"
                :message="
                  s__(
                    'ApplicationSettings|A user cap that exceeds the current licensed user count (%{licensedUserCount}) may result in a %{linkStart}true-up%{linkEnd}.',
                  )
                "
              >
                <template #licensedUserCount>{{ licensedUserCount }}</template>
                <template #link="{ content }">
                  <help-page-link
                    href="subscriptions/quarterly_reconciliation"
                    anchor="quarterly-reconciliation-versus-annual-true-ups"
                    >{{ content }}</help-page-link
                  >
                </template>
              </gl-sprintf>
            </small>
          </gl-form-group>
        </div>

        <gl-form-radio :value="$options.SEAT_CONTROL.OFF" data-testid="seat-controls-open-access">
          {{ s__('ApplicationSettings|Open access') }}
          <template #help>{{
            s__('ApplicationSettings|Invitations do not require administrator approval')
          }}</template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      v-if="promotionManagementAvailable"
      :label="s__('ApplicationSettings|Role Promotions')"
      label-for="role-promotions"
    >
      <seat-controls-member-promotion-management
        @form-value-change="$emit('form-value-change', $event)"
      />
    </gl-form-group>
  </div>
</template>
