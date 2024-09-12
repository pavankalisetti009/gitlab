import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockData } from 'jest/admin/signup_restrictions/mock_data';
import SignupForm from '~/pages/admin/application_settings/general/components/signup_form.vue';

describe('Signup Form', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mountComponent = ({ injectedProps = {} } = {}) => {
    wrapper = mountExtended(SignupForm, {
      provide: {
        glFeatures: {
          passwordComplexity: true,
        },
        ...mockData,
        ...injectedProps,
      },
      stubs: {
        SignupCheckbox: true,
      },
    });
  };

  describe('form data', () => {
    beforeEach(() => {
      mountComponent({
        injectedProps: {
          canDisableMemberPromotionManagement: false,
          rolePromotionRequestsPath: '',
        },
      });
    });

    it.each`
      prop                                 | propValue                                   | elementSelector                                                       | formElementPassedDataType | formElementKey | expected
      ${'passwordNumberRequired'}          | ${mockData.passwordNumberRequired}          | ${'[name="application_setting[password_number_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordNumberRequired}
      ${'passwordLowercaseRequired'}       | ${mockData.passwordLowercaseRequired}       | ${'[name="application_setting[password_lowercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordLowercaseRequired}
      ${'passwordUppercaseRequired'}       | ${mockData.passwordUppercaseRequired}       | ${'[name="application_setting[password_uppercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordUppercaseRequired}
      ${'passwordSymbolRequired'}          | ${mockData.passwordSymbolRequired}          | ${'[name="application_setting[password_symbol_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordSymbolRequired}
      ${'enableMemberPromotionManagement'} | ${mockData.enableMemberPromotionManagement} | ${'[name="application_setting[enable_member_promotion_management]"]'} | ${'prop'}                 | ${'value'}     | ${mockData.enableMemberPromotionManagement}
    `(
      'form element $elementSelector gets $expected value for $formElementKey $formElementPassedDataType when prop $prop is set to $propValue',
      ({ elementSelector, expected, formElementKey, formElementPassedDataType }) => {
        const formElement = wrapper.find(elementSelector);

        switch (formElementPassedDataType) {
          case 'attribute':
            expect(formElement.attributes(formElementKey)).toBe(expected);
            break;
          case 'prop':
            expect(formElement.props(formElementKey)).toBe(expected);
            break;
          case 'value':
            expect(formElement.element.value).toBe(expected);
            break;
          default:
            expect(formElement.props(formElementKey)).toBe(expected);
            break;
        }
      },
    );
  });
});
