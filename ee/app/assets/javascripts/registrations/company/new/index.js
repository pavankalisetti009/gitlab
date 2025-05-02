import Vue from 'vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import GlFieldErrors from '~/gl_field_errors';
import { parseBoolean } from '~/lib/utils/common_utils';

const mountCompanyForm = () => {
  const el = document.querySelector('#js-registrations-company-form');
  const {
    submitPath,
    firstName,
    lastName,
    showNameFields,
    emailDomain,
    formType,
    trackActionForErrors,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
        showNameFields: parseBoolean(showNameFields),
        emailDomain,
      },
      submitPath,
      trackActionForErrors,
      formType,
    },
    render(createElement) {
      return createElement(CompanyForm);
    },
  });
};

export default () => {
  mountCompanyForm();

  // Since we replaced form inputs, we need to re-initialize the field errors handler
  return new GlFieldErrors(document.querySelectorAll('.gl-show-field-errors'));
};
