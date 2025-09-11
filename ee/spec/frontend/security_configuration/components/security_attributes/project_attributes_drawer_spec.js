import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectAttributesDrawer from 'ee/security_configuration/security_attributes/components/project_attributes_drawer.vue';
import AttributesCategoryDropdown from 'ee/security_configuration/security_attributes/components/attributes_category_dropdown.vue';
import { mockSecurityAttributeCategories } from 'ee/security_configuration/security_attributes/graphql/resolvers';

describe('ProjectAttributesDrawer', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ProjectAttributesDrawer, {
      propsData: {
        open: true,
        categories: mockSecurityAttributeCategories,
        selectedAttributes: [],
      },
      stubs: {
        GlDrawer,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows a dropdown for each category', () => {
    expect(wrapper.findAllComponents(AttributesCategoryDropdown)).toHaveLength(5);
  });

  it('emits save event with selected attributes from all categories', () => {
    wrapper
      .findComponent(AttributesCategoryDropdown)
      .vm.$emit('change', { categoryId: 11, selectedAttributes: [1, 2, 3] });
    wrapper
      .findComponent(AttributesCategoryDropdown)
      .vm.$emit('change', { categoryId: 12, selectedAttributes: [9] });
    wrapper.findByTestId('submit-btn').vm.$emit('click');

    expect(wrapper.emitted('save')[0][0]).toEqual([1, 2, 3, 9]);
  });

  it('emits cancel event', () => {
    wrapper.findByTestId('cancel-btn').vm.$emit('click');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });
});
