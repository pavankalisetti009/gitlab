import {
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlBadge,
  GlLabel,
  GlButton,
  GlTableLite,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CategoryForm from 'ee/security_configuration/components/security_attributes/category_form.vue';
import {
  mockSecurityAttributeCategories,
  mockSecurityAttributes,
} from 'ee/security_configuration/graphql/resolvers';

const category = mockSecurityAttributeCategories[0];

describe('Category form', () => {
  let wrapper;

  const createComponent = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(CategoryForm, {
      propsData: {
        securityAttributes: mockSecurityAttributes,
        category,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlTableLite,
        GlDisclosureDropdown,
      },
    });
  };

  describe.each`
    description                  | id           | canEditCategory | canEditAttributes | multipleSelection
    ${'locked category'}         | ${1}         | ${false}        | ${false}          | ${false}
    ${'limited edits category'}  | ${2}         | ${false}        | ${true}           | ${true}
    ${'fully editable category'} | ${3}         | ${true}         | ${true}           | ${true}
    ${'new category'}            | ${undefined} | ${true}         | ${true}           | ${false}
  `('$description', ({ id, canEditCategory, canEditAttributes, multipleSelection }) => {
    describe('category metadata', () => {
      beforeEach(() => {
        createComponent({
          category: {
            ...category,
            id,
            canEditCategory,
            canEditAttributes,
            multipleSelection,
          },
        });
      });

      describe('badge', () => {
        if (canEditCategory && canEditAttributes) {
          it('is not shown', () => {
            expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
          });
        }
        if (canEditCategory && !canEditAttributes) {
          it('shows "limited edits allowed"', () => {
            expect(wrapper.findComponent(GlBadge).text()).toBe('Limited edits allowed');
          });
        }
        if (!canEditCategory && !canEditAttributes) {
          it('shows "category locked"', () => {
            expect(wrapper.findComponent(GlBadge).text()).toBe('Category locked');
          });
        }
      });

      if (canEditCategory) {
        it('renders the category name and description form fields', () => {
          expect(wrapper.findComponent(GlFormInput).props('value')).toBe(category.name);
          expect(wrapper.findComponent(GlFormTextarea).props('value')).toBe(category.description);
        });
      } else {
        it('renders the category name and description as text', () => {
          expect(wrapper.findAllComponents(GlFormGroup).at(0).text()).toContain(category.name);
          expect(wrapper.findAllComponents(GlFormGroup).at(1).text()).toContain(
            category.description,
          );
        });
      }

      it('renders the selection type', () => {
        // if category is new
        if (id === undefined) {
          expect(wrapper.findAllComponents(GlFormRadio).at(0).text()).toBe('Single selection');
          expect(wrapper.findAllComponents(GlFormRadio).at(1).text()).toBe('Multiple selection');
        } else if (multipleSelection) {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain(
            'Multiple selection',
          );
        } else {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain('Single selection');
        }
      });
    });

    describe('attributes', () => {
      beforeEach(() => {
        createComponent(
          {
            category: {
              ...category,
              id,
              canEditCategory,
              canEditAttributes,
              multipleSelection,
            },
          },
          mountExtended,
        );
      });

      // if category is not new (empty)
      if (id !== undefined) {
        it('renders the attributes in the category', () => {
          mockSecurityAttributes
            .filter((attribute) => attribute.categoryId === category.id)
            .forEach((attribute, index) => {
              expect(wrapper.findAllComponents(GlLabel).at(index).props('title')).toBe(
                attribute.name,
              );
              expect(
                wrapper.findComponent(GlTableLite).find('tbody').findAll('tr').at(index).text(),
              ).toContain(attribute.description);
              expect(wrapper.findAllComponents(GlLink).at(index).text()).toContain(
                `${attribute.projectCount} project`,
              );
            });
        });
      }

      if (canEditAttributes) {
        it('shows an attribute create button that emits addAttribute', async () => {
          wrapper.findComponent(GlButton).vm.$emit('click');
          await nextTick();

          expect(wrapper.emitted('addAttribute')).toStrictEqual([[]]);
        });
      }
      if (canEditAttributes && id !== undefined) {
        it('shows an attribute edit dropdown item that emits editAttribute', async () => {
          wrapper.findAllComponents(GlDisclosureDropdownItem).at(0).vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({ editAttribute: [[{ name: 'Asset Track' }]] });
        });
      }
      if (!canEditAttributes) {
        it('does not show attribute create/edit actions', () => {
          expect(wrapper.findComponent(GlButton).exists()).toBe(false);
          expect(wrapper.findComponent(GlDisclosureDropdownItem).exists()).toBe(false);
        });
      }
    });
  });
});
