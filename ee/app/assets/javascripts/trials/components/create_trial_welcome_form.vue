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
} from 'ee/vue_shared/leads/constants';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import {
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
  TRIAL_STATE_LABEL,
  TRIAL_STATE_PROMPT,
} from '../constants';

export default {
  name: 'CreateTrialWelcomeForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlSprintf,
    GlLink,
    GlFormFields,
    GlFormSelect,
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
      formValues: {
        first_name: this.userData.firstName,
        last_name: this.userData.lastName,
        company_name: this.userData.companyName,
        country: this.userData.country,
        state: this.userData.state,
        group_name: '',
        project_name: '',
      },
      countries: [],
      states: [],
    };
  },
  computed: {
    showCountry() {
      return !this.$apollo.queries.countries.loading;
    },
    countryOptionsWithDefault() {
      const countriesArray = Array.isArray(this.countries) ? this.countries : [];
      return [
        {
          name: LEADS_COUNTRY_PROMPT,
          id: '',
        },
        ...countriesArray,
      ];
    },
    stateRequired() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.formValues.country);
    },
    showState() {
      return !this.$apollo.queries.states.loading && this.formValues.country && this.stateRequired;
    },
    stateOptionsWithDefault() {
      const statesArray = Array.isArray(this.states) ? this.states : [];
      return [
        {
          name: TRIAL_STATE_PROMPT,
          id: '',
        },
        ...statesArray,
      ];
    },
    fields() {
      const result = {};

      result.first_name = {
        label: LEADS_FIRST_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12 md:gl-col-span-6',
        },
        inputAttrs: {
          name: 'first_name',
          'data-testid': 'first-name-field',
        },
        validators: [formValidators.required(__('First name is required.'))],
      };

      result.last_name = {
        label: LEADS_LAST_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12 md:gl-col-span-6',
        },
        inputAttrs: {
          name: 'last_name',
          'data-testid': 'last-name-field',
        },
        validators: [formValidators.required(__('Last name is required.'))],
      };

      result.company_name = {
        label: LEADS_COMPANY_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'company_name',
        },
        validators: [formValidators.required(__('Company name is required.'))],
      };

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          validators: [formValidators.required(__('Country or region is required.'))],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
            },
            validators: [formValidators.required(__('State or province is required.'))],
          };
        }
      }

      result.group_name = {
        label: __('Group name'),
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'group_name',
          'data-testid': 'group-name-input',
          placeholder: __('You use groups to organize your projects'),
        },
        validators: [formValidators.required(__('Group name is required.'))],
      };

      result.project_name = {
        label: __('Project name'),
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'project_name',
          'data-testid': 'project-name-input',
          placeholder: __('Projects contain the resources for your repository'),
        },
        validators: [formValidators.required(__('Project name is required.'))],
      };

      return result;
    },
  },
  watch: {
    'formValues.country': function handleCountryChange() {
      this.resetSelectedState();
    },
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.userData.emailDomain);
      this.$refs.form.$el.submit();
    },
    resetSelectedState() {
      if (!this.showState) {
        this.formValues.state = '';
      }
    },
  },
  apollo: {
    countries: {
      query: countriesQuery,
      result(result) {
        if (result.data && result.data.countries) {
          this.countries = Array.isArray(result.data.countries) ? result.data.countries : [];
        }
      },
      error() {
        this.countries = [];
      },
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.formValues.country;
      },
      variables() {
        return {
          countryId: this.formValues.country,
        };
      },
      result(result) {
        if (result.data && result.data.states) {
          this.states = Array.isArray(result.data.states) ? result.data.states : [];
        }
      },
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    buttonText: s__('Trial|Continue to GitLab'),
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
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid md:gl-gap-x-4"
      @submit="onSubmit"
    >
      <template #input(country)>
        <gl-form-select
          id="country"
          v-model="formValues.country"
          name="country"
          :options="countryOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="country-dropdown"
        />
      </template>

      <template #input(state)>
        <gl-form-select
          id="state"
          v-model="formValues.state"
          name="state"
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
