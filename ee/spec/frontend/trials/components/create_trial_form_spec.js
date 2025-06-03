import { GlForm, GlFormFields } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import CreateTrialForm from 'ee/trials/components/create_trial_form.vue';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from 'ee_jest/hand_raise_leads/components/mock_data';
import { TRIAL_PHONE_DESCRIPTION } from 'ee/trials/constants';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialLeadSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('CreateTrialForm', () => {
  let wrapper;
  const submitPath = '/some/path';
  const gtmSubmitEventLabel = '_gtm_submit_event_label_';

  const defaultUserData = {
    firstName: 'Joe',
    lastName: 'Smith',
    companyName: 'ACME',
    country: 'US',
    state: 'CA',
    phoneNumber: '192919',
    emailDomain: 'example.com',
    showNameFields: true,
  };

  const createComponent = async ({
    userData = defaultUserData,
    propsData = {},
    countriesLoading = false,
    statesLoading = false,
  } = {}) => {
    const mockResolvers = {
      Query: {
        countries() {
          if (countriesLoading) {
            return new Promise(() => {});
          }
          return COUNTRIES;
        },
        states() {
          if (statesLoading) {
            return new Promise(() => {});
          }
          return STATES;
        },
      },
    };

    const component = shallowMountExtended(CreateTrialForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        userData,
        submitPath,
        gtmSubmitEventLabel,
        ...propsData,
      },
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return component;
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findCountrySelect = () => wrapper.findByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findByTestId('state-dropdown');
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const fieldsProps = () => findFormFields().props('fields');
  const findHiddenInput = (name) => wrapper.findByTestId(`hidden-${name}`);

  describe('rendering', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    describe('with default props', () => {
      it('renders the form with correct action and method', () => {
        expect(findForm().attributes('action')).toBe(submitPath);
        expect(findForm().attributes('method')).toBe('post');
      });

      it('passes the correct fields to GlFormFields', () => {
        expect(findFormFields().exists()).toBe(true);

        const expectedFields = [
          { key: 'first_name', name: 'first_name' },
          { key: 'last_name', name: 'last_name' },
          { key: 'company_name', name: 'company_name' },
          { key: 'country', name: undefined },
          { key: 'state', name: undefined },
          { key: 'phone_number', name: 'phone_number' },
        ];

        expectedFields.forEach(({ key, name }) => {
          expect(fieldsProps()).toHaveProperty(key);

          if (name !== undefined) {
            expect(fieldsProps()[key].inputAttrs).toHaveProperty('name', name);
          }
        });
      });

      it('correctly binds initialFormValues to GlFormFields via v-model', async () => {
        expect(findFormFields().props('values')).toEqual(wrapper.vm.initialFormValues);

        const updatedValues = {
          ...wrapper.vm.initialFormValues,
          company_name: 'New Company Name',
        };

        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();

        expect(findFormFields().props('values')).toEqual(updatedValues);
      });
    });

    describe('with hidden name fields', () => {
      beforeEach(async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, showNameFields: false },
        });
      });

      it('does not include name fields in fields prop when showNameFields is false', () => {
        expect(fieldsProps()).not.toHaveProperty('first_name');
        expect(fieldsProps()).not.toHaveProperty('last_name');

        expect(findHiddenInput('first-name').attributes('value')).toBe(defaultUserData.firstName);
        expect(findHiddenInput('last-name').attributes('value')).toBe(defaultUserData.lastName);
      });
    });

    describe('country field', () => {
      it('returns false when Apollo is loading countries', async () => {
        wrapper = await createComponent({ countriesLoading: true });

        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('country');
      });

      it('returns true when Apollo is not loading countries', async () => {
        wrapper = await createComponent();

        await nextTick();

        expect(fieldsProps()).toHaveProperty('country');
      });
    });

    describe('state field', () => {
      it('returns false when Apollo is loading states', async () => {
        wrapper = await createComponent({ statesLoading: true });

        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('returns true when Apollo is not loading states', async () => {
        wrapper = await createComponent();

        await nextTick();

        expect(fieldsProps()).toHaveProperty('state');
      });
    });
  });

  describe('field validations', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    describe('name field validations', () => {
      it.each`
        value     | result
        ${null}   | ${'First name is required.'}
        ${''}     | ${'First name is required.'}
        ${'John'} | ${''}
      `('validates the first_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const firstNameValidator = fieldsProps().first_name.validators[0];
        expect(firstNameValidator(value)).toBe(result);
      });

      it.each`
        value    | result
        ${null}  | ${'Last name is required.'}
        ${''}    | ${'Last name is required.'}
        ${'Doe'} | ${''}
      `('validates the last_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const lastNameValidator = fieldsProps().last_name.validators[0];
        expect(lastNameValidator(value)).toBe(result);
      });
    });

    describe('company_name field validations', () => {
      it.each`
        value     | result
        ${null}   | ${'Company name is required.'}
        ${''}     | ${'Company name is required.'}
        ${'Acme'} | ${''}
      `('validates the company_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const companyNameValidator = fieldsProps().company_name.validators[0];
        expect(companyNameValidator(value)).toBe(result);
      });
    });

    describe('phone_number validations', () => {
      it.each`
        value                          | result
        ${'+1 (121) 22-12-23'}         | ${TRIAL_PHONE_DESCRIPTION}
        ${'+12190AX '}                 | ${TRIAL_PHONE_DESCRIPTION}
        ${'Tel:129120'}                | ${TRIAL_PHONE_DESCRIPTION}
        ${'11290+12'}                  | ${TRIAL_PHONE_DESCRIPTION}
        ${'++1121221223'}              | ${TRIAL_PHONE_DESCRIPTION}
        ${'+1121221223'}               | ${''}
        ${defaultUserData.phoneNumber} | ${''}
        ${''}                          | ${''}
      `('validates the phone number with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const phoneValidator = fieldsProps().phone_number.validators[0];

        expect(phoneValidator(value)).toBe(result);
      });
    });
  });

  describe('country and state field behavior', () => {
    it('renders country and state fields after countries are loaded', async () => {
      wrapper = await createComponent();
      await nextTick();

      expect(findCountrySelect().attributes('options').length).toBeGreaterThan(1);
      expect(findStateSelect().attributes('options').length).toBeGreaterThan(1);
    });

    it('has the proper state show and hide logic based on the selected country', async () => {
      wrapper = await createComponent();
      await nextTick();

      await findCountrySelect().vm.$emit('input', 'NL');
      await nextTick();

      expect(fieldsProps()).not.toHaveProperty('state');

      await findCountrySelect().vm.$emit('input', COUNTRY_WITH_STATES);
      await nextTick();

      expect(fieldsProps()).toHaveProperty('state');
    });

    it.each`
      selectedCountry        | selectedState | stateFieldExists | result
      ${COUNTRY_WITH_STATES} | ${null}       | ${true}          | ${'State or province is required.'}
      ${'NL'}                | ${null}       | ${false}         | ${''}
      ${COUNTRY_WITH_STATES} | ${STATE}      | ${true}          | ${''}
    `(
      'validates state with selectedCountry=$selectedCountry and selectedState=$selectedState',
      async ({ selectedCountry, selectedState, stateFieldExists, result }) => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: selectedCountry, state: selectedState },
        });

        const hasStateField = 'state' in fieldsProps();

        expect(hasStateField).toBe(stateFieldExists);

        if (hasStateField) {
          const stateValidator = fieldsProps().state.validators[0];
          expect(stateValidator()).toBe(result);
        }
      },
    );

    it.each`
      countryValue | result
      ${''}        | ${'Country or region is required.'}
      ${null}      | ${'Country or region is required.'}
      ${'US'}      | ${''}
      ${'NL'}      | ${''}
    `('validates country with value=$countryValue', async ({ countryValue, result }) => {
      wrapper = await createComponent({
        userData: { ...defaultUserData, country: countryValue },
      });

      const countryValidator = fieldsProps().country.validators[0];
      expect(countryValidator()).toBe(result);
    });
  });

  describe('submitting', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
      await nextTick();

      findFormFields().vm.$emit('input', wrapper.vm.initialFormValues);
    });

    it('tracks the saas Trial submitting', async () => {
      const submitSpy = jest.fn();
      const formElement = wrapper.vm.$refs.form.$el;
      formElement.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(trackSaasTrialLeadSubmit).toHaveBeenCalledWith(
        gtmSubmitEventLabel,
        defaultUserData.emailDomain,
      );

      expect(submitSpy).toHaveBeenCalled();
    });
  });
});
