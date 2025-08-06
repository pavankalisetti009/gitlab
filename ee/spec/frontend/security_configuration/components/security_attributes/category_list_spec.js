import { GlBadge, GlButton } from '@gitlab/ui';
import { mockSecurityAttributeCategories } from 'ee/security_configuration/security_attributes/graphql/resolvers';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CategoryList from 'ee/security_configuration/components/security_attributes/category_list.vue';

const firstCategory = mockSecurityAttributeCategories[0];
const secondCategory = mockSecurityAttributeCategories[1];

describe('Category list', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(CategoryList, {
      propsData: {
        securityAttributeCategories: mockSecurityAttributeCategories,
        selectedCategory: firstCategory,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the category name, description, and project count for each category', () => {
    expect(wrapper.text()).toContain(firstCategory.name);
    expect(wrapper.text()).toContain(firstCategory.description);
    expect(wrapper.findComponent(GlBadge).text()).toBe(firstCategory.attributeCount.toString());
  });

  it('emits selectCategory on category click', () => {
    wrapper.findByTestId(`attribute-category-${secondCategory.id}`).trigger('click');

    expect(wrapper.emitted('selectCategory')[0][0]).toBe(secondCategory);
  });

  it('emits selectCategory with empty category on "Create category" click', () => {
    wrapper.findComponent(GlButton).vm.$emit('click');

    expect(wrapper.emitted('selectCategory')[0][0]).toStrictEqual({});
  });
});
