<script>
import { GlForm, GlButton, GlSprintf, GlLink, GlFormFields, GlFormSelect } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/dist/utils';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES_WITH_STATES_ALLOWED,
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COUNTRY_LABEL,
  LEADS_COUNTRY_PROMPT,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import {
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
  TRIAL_STATE_LABEL,
  TRIAL_STATE_PROMPT,
} from '../constants';

export default {
  name: 'CreateTrialForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlSprintf,
    GlLink,
    GlFormFields,
    GlFormSelect,
  },
  directives: {
    autofocusonshow,
  },
  props: {
    userData: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    gtmSubmitEventLabel: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      initialFormValues: {
        first_name: this.userData.firstName,
        last_name: this.userData.lastName,
        company_name: this.userData.companyName,
        country: this.userData.country,
        phone_number: this.userData.phoneNumber,
      },
      selectedCountry: this.userData.country,
      selectedState: this.userData.state,
      countries: [],
      states: [],
    };
  },
  computed: {
    showCountry() {
      return !this.$apollo.queries.countries.loading;
    },
    countryOptionsWithDefault() {
      return [
        {
          name: LEADS_COUNTRY_PROMPT,
          id: '',
        },
        ...this.countries,
      ];
    },
    stateRequired() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.selectedCountry);
    },
    showState() {
      return !this.$apollo.queries.states.loading && this.selectedCountry && this.stateRequired;
    },
    stateOptionsWithDefault() {
      return [
        {
          name: TRIAL_STATE_PROMPT,
          id: '',
        },
        ...this.states,
      ];
    },
    fields() {
      const result = {};

      if (this.userData.showNameFields) {
        Object.assign(result, {
          first_name: {
            label: LEADS_FIRST_NAME_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12 md:gl-col-span-6',
            },
            inputAttrs: {
              name: 'first_name',
              'data-testid': 'first-name-field',
            },
            validators: [formValidators.required(__('First name is required.'))],
          },
          last_name: {
            label: LEADS_LAST_NAME_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12 md:gl-col-span-6',
            },
            inputAttrs: {
              name: 'last_name',
              'data-testid': 'last-name-field',
            },
            validators: [formValidators.required(__('Last name is required.'))],
          },
        });
      }

      Object.assign(result, {
        company_name: {
          label: LEADS_COMPANY_NAME_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          inputAttrs: {
            name: 'company_name',
          },
          validators: [formValidators.required(__('Company name is required.'))],
        },
      });

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          validators: [
            formValidators.factory(__('Country or region is required.'), () => {
              return this.selectedCountry;
            }),
          ],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
            },
            validators: [
              formValidators.factory(__('State or province is required.'), () => {
                return !this.stateRequired || (this.stateRequired && this.selectedState);
              }),
            ],
          };
        }
      }

      result.phone_number = {
        label: LEADS_PHONE_NUMBER_LABEL,
        groupAttrs: {
          optional: true,
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'phone_number',
        },
        validators: [
          formValidators.factory(TRIAL_PHONE_DESCRIPTION, (val) => {
            if (!val || val.trim() === '') {
              return true;
            }

            return /^\+?[0-9\-\s]+$/.test(val);
          }),
        ],
      };

      return result;
    },
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.userData.emailDomain);
      this.$refs.form.$el.submit();
    },
    resetSelectedState() {
      if (!this.showState) {
        this.selectedState = '';
      }
    },
  },
  apollo: {
    countries: {
      query: countriesQuery,
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.selectedCountry;
      },
      variables() {
        return {
          countryId: this.selectedCountry,
        };
      },
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    buttonText: s__('Trial|Activate my trial'),
    termsText: TRIAL_TERMS_TEXT,
    gitlabSubscription: TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
    privacyStatement: TRIAL_PRIVACY_STATEMENT,
    cookiePolicy: TRIAL_COOKIE_POLICY,
  },
  formId: 'create-trial-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    method="post"
    class="gl-border-1 gl-border-solid gl-border-gray-100 gl-p-6"
    data-testid="trial-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />

    <gl-form-fields
      v-model="initialFormValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid md:gl-gap-x-4"
      @submit="onSubmit"
    >
      <template v-if="!userData.showNameFields" #after(company_name)>
        <input
          type="hidden"
          :value="userData.firstName"
          name="first_name"
          data-testid="hidden-first-name"
        />
        <input
          type="hidden"
          :value="userData.lastName"
          name="last_name"
          data-testid="hidden-last-name"
        />
      </template>
      <template #input(country)>
        <gl-form-select
          id="country"
          v-model="selectedCountry"
          name="country"
          class="gl-field-error-anchor"
          :options="countryOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="country-dropdown"
          @change="resetSelectedState"
        />
      </template>
      <template #input(state)>
        <gl-form-select
          id="state"
          v-model="selectedState"
          v-autofocusonshow
          name="state"
          class="gl-field-error-anchor"
          :options="stateOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="state-dropdown"
        />
      </template>
    </gl-form-fields>
    <gl-button
      type="submit"
      variant="confirm"
      data-testid="continue-button"
      class="js-no-auto-disable gl-w-full"
    >
      {{ $options.i18n.buttonText }}
    </gl-button>

    <div class="gl-mt-4">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #buttonText>{{ $options.i18n.buttonText }}</template>
        <template #gitlabSubscriptionAgreement>
          <gl-link :href="$options.i18n.gitlabSubscription.url" target="_blank">
            {{ $options.i18n.gitlabSubscription.text }}
          </gl-link>
        </template>
        <template #privacyStatement>
          <gl-link :href="$options.i18n.privacyStatement.url" target="_blank">
            {{ $options.i18n.privacyStatement.text }}
          </gl-link>
        </template>
        <template #cookiePolicy>
          <gl-link :href="$options.i18n.cookiePolicy.url" target="_blank">
            {{ $options.i18n.cookiePolicy.text }}
          </gl-link>
        </template>
      </gl-sprintf>
    </div>
  </gl-form>
</template>
