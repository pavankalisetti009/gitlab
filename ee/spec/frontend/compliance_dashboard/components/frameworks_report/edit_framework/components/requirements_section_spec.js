import { GlTable } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockRequirements, mockRequirementControls } from 'ee_jest/compliance_dashboard/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import controlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Requirements section', () => {
  let wrapper;

  const error = new Error('GraphQL error');

  let controlsQueryHandler;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findNewRequirementButton = () => wrapper.findByTestId('add-requirement-button');
  const findRequirementModal = () => wrapper.findComponent(RequirementModal);

  const createComponent = async (controlsQueryHandlerMockResponse = controlsQueryHandler) => {
    const mockApollo = createMockApollo([[controlsQuery, controlsQueryHandlerMockResponse]]);

    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements: mockRequirements,
        isNewFramework: true,
      },
      apolloProvider: mockApollo,
    });

    await waitForPromises();
  };

  describe('Rendering', () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockRequirementControls,
        },
      },
    });
    beforeEach(async () => {
      await createComponent();
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

    it.each`
      idx  | name        | description                  | controls
      ${0} | ${'SOC2'}   | ${'Controls for SOC2'}       | ${['Minimum approvals required']}
      ${1} | ${'GitLab'} | ${'Controls used by GitLab'} | ${['Minimum approvals required', 'SAST Running']}
    `('has the correct data for row $idx', ({ idx, name, description, controls }) => {
      const frameworkRequirements = findTableRowData(idx);

      expect(frameworkRequirements.at(0).text()).toBe(name);
      expect(frameworkRequirements.at(1).text()).toBe(description);
      expect(
        frameworkRequirements
          .at(2)
          .findAll('li')
          .wrappers.map((w) => w.text()),
      ).toEqual(controls);
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

  describe('Fetching data', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockRequirementControls,
          },
        },
      });
      createComponent();
    });

    it('calls the complianceRequirementControls query', () => {
      expect(controlsQueryHandler).toHaveBeenCalled();
    });

    it('updates data', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('requirementControls')).toMatchObject(
        mockRequirementControls,
      );
    });
  });

  describe('Error handling', () => {
    beforeEach(async () => {
      controlsQueryHandler = jest.fn().mockRejectedValue(error);
      await createComponent(controlsQueryHandler);
    });

    it('calls createAlert with the correct message on query error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error fetching compliance requirements controls data. Please refresh the page.',
        captureException: true,
        error,
      });
    });
  });
});
