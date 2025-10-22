import { GlLabel } from '@gitlab/ui';
import AttributesCell from 'ee/security_inventory/components/attributes_cell.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockSecurityAttributes } from 'ee/security_configuration/security_attributes/graphql/resolvers';
import { VISIBLE_ATTRIBUTE_COUNT } from 'ee/security_inventory/constants';
import { subgroupsAndProjects } from '../mock_data';

describe('AttributesCell', () => {
  let wrapper;

  const mockProject = subgroupsAndProjects.data.namespaceSecurityProjects.edges[0].node;
  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];

  const createComponent = (props = {}, provide = { canManageAttributes: false }) => {
    wrapper = shallowMountExtended(AttributesCell, {
      provide,
      propsData: {
        ...props,
      },
    });
  };

  const findVisibleAttributes = () =>
    wrapper.findByTestId('visible-attributes').findAllComponents(GlLabel);
  const findOverflowAttribute = () => wrapper.findByTestId('overflow-attribute');
  const findAllAttributes = () => wrapper.findByTestId('all-attributes');

  describe('project view', () => {
    describe(`with more than ${VISIBLE_ATTRIBUTE_COUNT} attributes`, () => {
      const attributeCount = VISIBLE_ATTRIBUTE_COUNT + 2;

      beforeEach(() => {
        createComponent({
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: mockSecurityAttributes.slice(0, attributeCount),
            },
          },
          index: 0,
        });
      });

      it(`renders the first ${VISIBLE_ATTRIBUTE_COUNT} attributes in the cell`, () => {
        expect(findVisibleAttributes()).toHaveLength(VISIBLE_ATTRIBUTE_COUNT);
      });

      it('renders the overflow attribute and the full list of attributes in popover', () => {
        expect(findOverflowAttribute().props('title')).toBe('+2 more');
        expect(findAllAttributes().findAllComponents(GlLabel)).toHaveLength(attributeCount);
      });
    });

    describe(`with ${VISIBLE_ATTRIBUTE_COUNT} or fewer attributes`, () => {
      const attributeCount = VISIBLE_ATTRIBUTE_COUNT;

      beforeEach(() => {
        createComponent({
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: mockSecurityAttributes.slice(0, attributeCount),
            },
          },
          index: 0,
        });
      });

      it('renders the attributes in the cell', () => {
        expect(findVisibleAttributes()).toHaveLength(VISIBLE_ATTRIBUTE_COUNT);
      });

      it('does not render the overflow attribute or popover', () => {
        expect(findOverflowAttribute().exists()).toBe(false);
        expect(findAllAttributes().exists()).toBe(false);
      });
    });

    it.each`
      description                                | canManageAttributes
      ${'renders add attributes action'}         | ${true}
      ${'does not render add attributes action'} | ${false}
    `('$description with canManageAttributes $canManageAttributes', ({ canManageAttributes }) => {
      createComponent(
        {
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: [],
            },
          },
          index: 0,
        },
        { canManageAttributes },
      );

      expect(wrapper.text().includes('+ Add attributes')).toBe(canManageAttributes);
    });
  });

  describe('group view', () => {
    beforeEach(() => {
      createComponent({ item: mockGroup, index: 0 });
    });

    it('renders an empty cell', () => {
      expect(wrapper.text()).toBe('');
    });
  });
});
