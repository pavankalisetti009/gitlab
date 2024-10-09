import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AiModelsForm from 'ee/ai/settings/components/ai_models_form.vue';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

describe('AiModelsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(AiModelsForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
          GlSprintf,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { selfHostedModelsEnabled: true } });
  });

  const findTitle = () => wrapper.find('h3').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findCheckboxLabel = () => wrapper.findByTestId('ai-models-checkbox-label');
  const findCheckboxHelpText = () => wrapper.find('.help-text');
  const findTestingAgreementLink = () => wrapper.findComponent(PromoPageLink);

  it('has the correct title', () => {
    expect(findTitle()).toBe('AI models');
  });

  it('has the correct label', () => {
    expect(findCheckboxLabel().text()).toBe('Allow use of self-hosted models');
  });

  describe('when self-hosted models have been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { selfHostedModelsEnabled: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().attributes('checked')).toBeDefined();
    });

    it('disables the checkbox', () => {
      expect(findCheckbox().attributes('disabled')).toBeDefined();
    });

    describe('help text', () => {
      it('renders the correct text', () => {
        expect(findCheckboxHelpText().text().replace(/\s+/g, ' ')).toMatch(
          'You have enabled self-hosted models and agreed to the GitLab Testing Agreement',
        );
      });

      it('links to the testing agreement', () => {
        expect(findTestingAgreementLink().attributes('path')).toBe(
          '/handbook/legal/testing-agreement/',
        );
      });
    });
  });

  describe('when self-hosted models have not been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { selfHostedModelsEnabled: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().attributes('checked')).toBeUndefined();
    });

    it('does not disable the checkbox', () => {
      expect(findCheckbox().attributes('disabled')).toBeUndefined();
    });

    describe('help text', () => {
      it('renders the correct text', () => {
        expect(findCheckboxHelpText().text().replace(/\s+/g, ' ')).toMatch(
          'By enabling self-hosted models, you agree to the GitLab Testing Agreement',
        );
      });

      it('links to the testing agreement', () => {
        expect(findTestingAgreementLink().attributes('path')).toBe(
          '/handbook/legal/testing-agreement/',
        );
      });
    });
  });
});
