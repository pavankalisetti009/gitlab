import { shallowMount } from '@vue/test-utils';
import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';

const MOCK_DATA = {
  experimentBetaHelpPath: '/help/policy/experiment-beta-support',
  testingAgreementPath: `/handbook/legal/testing-agreement/`,
};

describe('DuoExperimentBetaFeaturesForm', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    return shallowMount(DuoExperimentBetaFeaturesForm, {
      propsData: {
        disabledCheckbox: false,
        experimentFeaturesEnabled: false,
        ...props,
      },
      provide: {
        areExperimentSettingsAllowed: true,
        ...provide,
      },
      stubs: {
        GlLink,
        GlSprintf,
        GlFormGroup,
        GlFormCheckbox,
        GlPopover,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('when areExperimentSettingsAllowed is false', () => {
    it('does not render the form group', () => {
      wrapper = createComponent(
        {},
        {
          areExperimentSettingsAllowed: false,
        },
      );
      expect(findFormGroup().exists()).toBe(false);
    });
  });

  describe('when areExperimentSettingsAllowed is true', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the title and form group', () => {
      expect(wrapper.find('h5').text()).toBe('GitLab Duo experiment and beta features');
      expect(findFormGroup().exists()).toBe(true);
    });

    it('renders the checkbox with correct label', () => {
      expect(findFormCheckbox().exists()).toBe(true);
      expect(findFormCheckbox().text()).toContain('Use experiment and beta GitLab Duo features');
    });

    it('sets initial checkbox state based on experimentFeaturesEnabled prop when unselected', () => {
      expect(findFormCheckbox().attributes('checked')).toBe(undefined);
    });

    it('emits change event when checkbox is clicked', () => {
      findFormCheckbox().vm.$emit('change');
      expect(findFormCheckbox().attributes('value')).toBe('true');
    });

    it('does not show popover when disabledCheckbox prop is false', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it('renders correct links', () => {
      const experimentBetaHelpLink = wrapper.findComponent(GlLink);
      const testingAgreementLink = wrapper.findComponent(PromoPageLink);
      expect(experimentBetaHelpLink.attributes('href')).toBe(MOCK_DATA.experimentBetaHelpPath);
      expect(testingAgreementLink.props('path')).toBe(MOCK_DATA.testingAgreementPath);
    });
  });

  describe('when areExperimentSettingsAllowed is true and disabledCheckbox is true', () => {
    beforeEach(() => {
      wrapper = createComponent({ disabledCheckbox: true });
    });

    it('disables checkbox', () => {
      expect(findFormCheckbox().attributes('disabled')).toBe('true');
    });

    it('shows popover', () => {
      expect(findPopover().exists()).toBe(true);
    });
  });
});
