import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import AttributesCategoryDropdown from 'ee/security_configuration/security_attributes/components/attributes_category_dropdown.vue';
import waitForPromises from 'helpers/wait_for_promises';
import getSecurityAttributesByCategoryQuery from 'ee/security_configuration/graphql/client/security_attributes_by_category.query.graphql';
import {
  mockSecurityAttributeCategories,
  mockSecurityAttributes,
} from 'ee/security_configuration/security_attributes/graphql/resolvers';

const mockMultipleSelection = {
  category: mockSecurityAttributeCategories[0],
  attributes: mockSecurityAttributes.filter((attribute) => attribute.categoryId === 11),
  selectedAttributesInCategory: [
    { id: 1, text: 'Asset Track' },
    { id: 2, text: 'Bank Branch' },
    { id: 3, text: 'Capital Commit' },
  ],
};
const mockSingleSelection = {
  category: mockSecurityAttributeCategories[1],
  attributes: mockSecurityAttributes.filter((attribute) => attribute.categoryId === 12),
  selectedAttributesInCategory: [{ id: 13, text: 'Non-essential' }],
};

Vue.use(VueApollo);

describe('AttributesCategoryDropdown', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const groupAttributesQueryHandler = jest.fn().mockImplementation(({ categoryId }) => ({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityAttributes: {
          nodes: mockSecurityAttributes.filter((attribute) => attribute.categoryId === categoryId),
        },
      },
    },
  }));

  const createComponent = ({
    category = {},
    selectedAttributesInCategory = [],
    requestHandlers = [[getSecurityAttributesByCategoryQuery, groupAttributesQueryHandler]],
  } = {}) => {
    const apolloProvider = createMockApollo(requestHandlers);
    wrapper = shallowMount(AttributesCategoryDropdown, {
      provide: { groupFullPath: 'path/to/group' },
      apolloProvider,
      propsData: {
        category,
        projectAttributes: [],
        selectedAttributesInCategory,
      },
    });
  };

  describe.each`
    description             | category                          | selectedAttributesInCategory
    ${'multiple selection'} | ${mockMultipleSelection.category} | ${mockMultipleSelection.selectedAttributesInCategory}
    ${'single selection'}   | ${mockSingleSelection.category}   | ${mockSingleSelection.selectedAttributesInCategory}
  `('$description category', ({ category, selectedAttributesInCategory }) => {
    beforeEach(async () => {
      createComponent({
        category,
        selectedAttributesInCategory,
      });

      await waitForPromises();
    });

    it('loads and lists attributes in the category', () => {
      expect(groupAttributesQueryHandler).toHaveBeenCalledWith({
        categoryId: category.id,
        fullPath: 'path/to/group',
      });
      expect(findListbox().props('items')).toMatchObject(
        mockSecurityAttributes
          .filter((attribute) => attribute.categoryId === category.id)
          .map(({ id, name }) => ({ id, text: name })),
      );
    });

    it('filters items based on search', async () => {
      findListbox().vm.$emit('search', 'ra');

      await nextTick();

      expect(findListbox().props('items')).toHaveLength(2);
    });

    it('allows multiple selection depending on the category', () => {
      expect(findListbox().props('multiple')).toBe(category.multipleSelection);
    });
  });

  describe('multiple selection behavior', () => {
    beforeEach(async () => {
      createComponent({
        category: mockMultipleSelection.category,
        selectedAttributesInCategory: mockMultipleSelection.selectedAttributesInCategory,
      });

      await waitForPromises();
    });

    it('starts out with the attributes passed in props selected', () => {
      expect(findListbox().props('selected')).toStrictEqual([1, 2, 3]);
      expect(findListbox().props('toggleText')).toBe('Asset Track, Bank Branch, +1 more');
    });

    it('changes selection', async () => {
      findListbox().vm.$emit('select', [1, 3, 4]);

      await nextTick();

      expect(findListbox().props('selected')).toStrictEqual([1, 3, 4]);
      expect(findListbox().props('toggleText')).toBe('Asset Track, Capital Commit, +1 more');
    });

    it('clears selection', async () => {
      findListbox().vm.$emit('reset');

      await nextTick();

      expect(findListbox().props('selected')).toStrictEqual([]);
      expect(findListbox().props('toggleText')).toBe('None');
    });
  });

  describe('single selection behavior', () => {
    beforeEach(async () => {
      createComponent({
        category: mockSingleSelection.category,
        selectedAttributesInCategory: mockSingleSelection.selectedAttributesInCategory,
      });

      await waitForPromises();
    });

    it('starts out with the attribute passed in props selected', () => {
      expect(findListbox().props('selected')).toStrictEqual(13);
      expect(findListbox().props('toggleText')).toBe('Non-essential');
    });

    it('changes selection', async () => {
      findListbox().vm.$emit('select', 12);

      await nextTick();

      expect(findListbox().props('selected')).toStrictEqual(12);
      expect(findListbox().props('toggleText')).toBe('Business Administrative');
    });

    it('clears selection', async () => {
      findListbox().vm.$emit('reset');

      await nextTick();

      expect(findListbox().props('selected')).toStrictEqual(null);
      expect(findListbox().props('toggleText')).toBe('None');
    });
  });
});
