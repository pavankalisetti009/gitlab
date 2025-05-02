import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import { DOCS_URL } from 'jh_else_ce/lib/utils/url_utility';

const requirementsPath = `${DOCS_URL}/subscriptions/subscription-add-ons#gitlab-duo-core`;
const mockTermsPath = `/handbook/legal/ai-functionality-terms/`;

describe('DuoCoreFeaturesForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    return shallowMountExtended(DuoCoreFeaturesForm, {
      propsData: {
        duoCoreFeaturesEnabled: false,
        ...props,
      },
      provide: {
        isSaaS: true,
        ...provide,
      },
      stubs: {
        GlLink,
        GlSprintf,
        GlFormGroup,
        GlFormCheckbox,
      },
    });
  };

  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the title', () => {
    expect(wrapper.text()).toMatch('Gitlab Duo Core');
  });

  it('renders the subtitle', () => {
    expect(wrapper.text()).toMatch(
      'When turned on, all billable users can access GitLab Duo Chat and Code Suggestions in supported IDEs.',
    );
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().exists()).toBe(true);
    expect(findFormCheckbox().text()).toContain('Turn on IDE features');
  });

  it('sets initial checkbox state based on duoCoreFeaturesEnabled prop when unselected', () => {
    expect(findFormCheckbox().attributes('checked')).toBe(undefined);
  });

  it('emits change event when checkbox is clicked', () => {
    findFormCheckbox().vm.$emit('change');
    expect(wrapper.emitted('change')).toEqual([[false]]);
  });

  it('renders correct links', () => {
    expect(wrapper.findComponent(PromoPageLink).props('path')).toBe(mockTermsPath);
    expect(wrapper.findComponent(GlLink).props('href')).toBe(requirementsPath);
  });

  it('renders the description', () => {
    expect(wrapper.text()).toMatch('Subgroup and project access controls are coming soon.');
  });

  describe('on SaaS', () => {
    it('renders the namespace description', () => {
      wrapper = createComponent({ provide: { isSaaS: true } });

      expect(wrapper.text()).toMatch('This settings applies to the whole top-level group.');
    });
  });

  describe('on Self-Managed', () => {
    it('renders the instance description', () => {
      wrapper = createComponent({ provide: { isSaaS: false } });

      expect(wrapper.text()).toMatch('This settings applies to the whole instance.');
    });
  });
});
