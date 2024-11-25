import Vue from 'vue';
import apolloProvider from 'ee/subscriptions/buy_addons_shared/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';

export default () => {
  const el = document.querySelector('#js-registrations-company-form');
  const { submitPath, firstName, lastName, emailDomain, formType, trackActionForErrors } =
    el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
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
