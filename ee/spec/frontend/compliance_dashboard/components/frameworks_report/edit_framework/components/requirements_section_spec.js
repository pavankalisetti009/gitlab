import { GlTable } from '@gitlab/ui';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockRequirements } from 'ee_jest/compliance_dashboard/mock_data';

describe('Requirements section', () => {
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findNewRequirementButton = () => wrapper.findByTestId('add-requirement-button');

  const createComponent = () => {
    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements: mockRequirements,
        isNewFramework: true,
      },
    });
  };

  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('Has title', () => {
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
    });
  });
  describe('Create requirement button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders create requirement', () => {
      expect(findNewRequirementButton().text()).toBe('New requirement');
    });
  });
});
