import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WorkflowInfo from 'ee/ai/duo_agents_platform/pages/show/components/workflow_info.vue';

describe('WorkflowInfo', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WorkflowInfo, {
      propsData: {
        isLoading: false,
        status: 'RUNNING',
        workflowDefinition: 'software_development',
        ...props,
      },
    });
  };

  const findListItems = () => wrapper.findAll('li');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
        status: 'RUNNING',
        workflowDefinition: 'software_development',
      });
    });

    it('renders UI copy as usual', () => {
      expect(findListItems()).toHaveLength(2);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(2);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    it.each`
      status       | workflowDefinition        | expectedStatus | expectedType
      ${'STOPPED'} | ${'software_development'} | ${'STOPPED'}   | ${'software_development'}
      ${'STARTED'} | ${'testing'}              | ${'STARTED'}   | ${'testing'}
      ${''}        | ${'something_else'}       | ${'N/A'}       | ${'something_else'}
      ${'RUNNING'} | ${''}                     | ${'RUNNING'}   | ${'N/A'}
      ${''}        | ${''}                     | ${'N/A'}       | ${'N/A'}
    `(
      'renders expected values when status is $status and definition is `$workflowDefinition`',
      ({ status, workflowDefinition, expectedStatus, expectedType }) => {
        createComponent({ status, workflowDefinition });

        expect(findListItems().at(0).text()).toContain(`Status: ${expectedStatus}`);
        expect(findListItems().at(1).text()).toContain(`Type: ${expectedType}`);
      },
    );
  });
});
