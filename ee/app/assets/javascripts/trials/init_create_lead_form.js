import Vue from 'vue';
import TrialCreateLeadForm from 'ee/trials/components/trial_create_lead_form.vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';

export const initTrialCreateLeadForm = (gtmSubmitEventLabel) => {
  const el = document.querySelector('#js-trial-create-lead-form');

  if (!el) {
    return false;
  }

  const {
    submitPath,
    firstName,
    lastName,
    showNameFields,
    companyName,
    companySize,
    country,
    state,
    phoneNumber,
    submitButtonText,
    emailDomain,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
        showNameFields: parseBoolean(showNameFields),
        companyName,
        companySize: companySize || null,
        country: country || '',
        state: state || '',
        phoneNumber,
        emailDomain,
      },
      submitPath,
      gtmSubmitEventLabel,
      submitButtonText,
    },
    render(createElement) {
      return createElement(TrialCreateLeadForm);
    },
  });
};
