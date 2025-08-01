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
import {
  mockSecurityAttributeCategories,
  mockSecurityAttributes,
} from 'ee/security_configuration/security_attributes/graphql/resolvers';
import {
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
} from 'ee/security_configuration/components/security_attributes/constants';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CategoryForm from 'ee/security_configuration/components/security_attributes/category_form.vue';

const category = mockSecurityAttributeCategories[0];
const expectedAttributes = mockSecurityAttributes.filter(
  (attribute) => attribute.categoryId === category.id,
);

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
    description                  | id           | editableState                  | multipleSelection | expectedBadge
    ${'locked category'}         | ${1}         | ${CATEGORY_LOCKED}             | ${false}          | ${'Category locked'}
    ${'limited edits category'}  | ${2}         | ${CATEGORY_PARTIALLY_EDITABLE} | ${true}           | ${'Limited edits allowed'}
    ${'fully editable category'} | ${3}         | ${CATEGORY_EDITABLE}           | ${true}           | ${false}
    ${'new category'}            | ${undefined} | ${CATEGORY_EDITABLE}           | ${false}          | ${false}
  `('$description', ({ id, editableState, multipleSelection, expectedBadge }) => {
    describe('category metadata', () => {
      beforeEach(() => {
        createComponent({
          category: {
            ...category,
            id,
            editableState,
            multipleSelection,
          },
        });
      });

      it('shows the appropriate badge', () => {
        if (expectedBadge === false) expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
        else expect(wrapper.findComponent(GlBadge).text()).toBe(expectedBadge);
      });

      if (editableState === CATEGORY_EDITABLE) {
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
              editableState,
              multipleSelection,
            },
          },
          mountExtended,
        );
      });

      // if category is not new (empty)
      if (id !== undefined) {
        it('renders the attributes in the category', () => {
          expectedAttributes.forEach((attribute, index) => {
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

      if (editableState !== CATEGORY_LOCKED) {
        it('shows an attribute create button that emits addAttribute', async () => {
          wrapper.findComponent(GlButton).vm.$emit('click');
          await nextTick();

          expect(wrapper.emitted('addAttribute')).toStrictEqual([[]]);
        });
      }
      if (editableState !== CATEGORY_LOCKED && id !== undefined) {
        it('shows an attribute edit dropdown item that emits editAttribute', async () => {
          wrapper.findAllComponents(GlDisclosureDropdownItem).at(0).vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({ editAttribute: [[{ name: 'Asset Track' }]] });
        });
      }
      if (editableState === CATEGORY_LOCKED) {
        it('does not show attribute create/edit actions', () => {
          expect(wrapper.findComponent(GlButton).exists()).toBe(false);
          expect(wrapper.findComponent(GlDisclosureDropdownItem).exists()).toBe(false);
        });
      }
    });
  });
});
