import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';

const mockTermsPath = `/handbook/legal/ai-functionality-terms/`;

describe('DuoCoreFeaturesForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMountExtended(DuoCoreFeaturesForm, {
      propsData: {
        duoCoreFeaturesEnabled: false,
        ...props,
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
    expect(wrapper.find('h5').text()).toBe('Gitlab Duo Core');
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
    const termsPath = wrapper.findComponent(PromoPageLink);
    expect(termsPath.props('path')).toBe(mockTermsPath);
  });
});
