import { GlTable } from '@gitlab/ui';

import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';

import { mountExtended } from 'helpers/vue_test_utils_helper';

const mockRequirements = [
  {
    __typename: 'ComplianceRequirement',
    id: 'gid://gitlab/Requirement/1',
    name: 'SOC2',
    description: 'Controls for SOC2',
    requirementType: 'internal',
    controlExpression: {
      __typename: 'ControlExpressionConnection',
      nodes: [
        {
          id: 'gid://gitlab/Control/1',
          name: 'At least one non-author approval',
          __typename: 'ControlExpression',
        },
      ],
    },
  },
  {
    __typename: 'ComplianceRequirement',
    id: 'gid://gitlab/Requirement/2',
    name: 'GitLab',
    description: 'Controls used by GitLab',
    requirementType: 'internal',
    controlExpression: {
      __typename: 'ControlExpressionConnection',
      nodes: [
        {
          id: 'gid://gitlab/Control/2',
          name: 'At least two approvals',
          __typename: 'ControlExpression',
        },
        {
          id: 'gid://gitlab/Control/3',
          name: 'Prevent commiters as approvers',
          __typename: 'ControlExpression',
        },
        {
          id: 'gid://gitlab/Control/4',
          name: 'Prevent auhors as approvers',
          __typename: 'ControlExpression',
        },
      ],
    },
  },
];

describe('Requirements section', () => {
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');

  const createComponent = () => {
    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements: mockRequirements,
      },
    });
  };

  describe('when loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Requirements');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'Configure requirements set forth by laws, regulations, and industry standards.',
      );
      expect(description.exists()).toBe(true);
    });

    it('correctly calculates requirements', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(mockRequirements.length);
    });

    it.each(Object.keys(mockRequirements))('has the correct data for row %s', (idx) => {
      const frameworkRequirements = findTableRowData(idx).wrappers.map((d) => d.text());

      expect(frameworkRequirements[0]).toMatch(mockRequirements[idx].name);
      expect(frameworkRequirements[1]).toMatch(mockRequirements[idx].description);
      expect(frameworkRequirements[2]).toMatch(
        mockRequirements[idx].controlExpression.nodes[0].name,
      );
    });
  });
});
