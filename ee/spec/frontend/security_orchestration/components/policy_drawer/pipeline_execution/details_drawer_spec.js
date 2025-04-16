import { GlLink } from '@gitlab/ui';
import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockProjectPipelineExecutionPolicy,
  mockProjectPipelineExecutionWithConfigurationPolicy,
  mockSchedulePipelineExecutionPolicy,
  mockSnoozeSchedulePipelineExecutionPolicy,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

describe('PipelineExecutionDrawer', () => {
  let wrapper;

  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findSchedule = () => wrapper.findByTestId('schedule-summary');
  const findSummaryHeader = () => wrapper.findByTestId('summary-header');
  const findSummaryFields = () => wrapper.findAllByTestId('summary-fields');
  const findProjectSummary = () => wrapper.findByTestId('project');
  const findFileSummary = () => wrapper.findByTestId('file');
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findLink = (parent) => parent.findComponent(GlLink);
  const findConfigurationRow = () => wrapper.findByTestId('policy-configuration');
  const findSnoozeSummary = () => wrapper.findByTestId('snooze-summary');

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(PipelineExecutionDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, ...provide },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('policy')).toEqual(mockProjectPipelineExecutionPolicy);
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces pipeline execution with configuration from external file',
      );
    });

    it('renders layout if yaml is invalid', () => {
      createComponent({ propsData: { policy: {} } });

      expect(findPolicyDrawerLayout().exists()).toBe(true);
      expect(findPolicyDrawerLayout().props('description')).toBe('');
    });
  });
  describe('schedules summary', () => {
    it('does not render if there are no schedules', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findSchedule().exists()).toBe(false);
    });

    it('renders if there are are schedules', () => {
      createComponent({ propsData: { policy: mockSchedulePipelineExecutionPolicy } });
      expect(findSchedule().exists()).toBe(true);
      expect(findSchedule().text()).toBe(
        'Schedule the following pipeline execution policy to run for default branch daily at 00:00 and run for 1 hour in timezone America/New_York.',
      );
    });

    it('does not render the snooze info if it exists', () => {
      createComponent({ propsData: { policy: mockSchedulePipelineExecutionPolicy } });
      expect(findSnoozeSummary().exists()).toBe(false);
    });

    it('renders the snooze info if it exists', () => {
      createComponent({ propsData: { policy: mockSnoozeSchedulePipelineExecutionPolicy } });
      expect(findSnoozeSummary().exists()).toBe(true);
    });
  });

  describe('summary', () => {
    it('renders paragraph policy summary as text', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      expect(findSummary().exists()).toBe(true);
      expect(findConfigurationRow().exists()).toBe(true);
      expect(findSummaryFields()).toHaveLength(1);
      const text = trimText(findSummaryFields().at(0).text());
      expect(text).toContain('Project : gitlab-policies/js6');
      expect(text).toContain('Reference : main');
      expect(text).toContain('Path : pipeline_execution_jobs.yml');
      expect(findSummaryHeader().text()).toBe('Enforce the following pipeline execution policy:');
    });

    it('renders the policy summary as a link for the project field', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      const link = findLink(findProjectSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/gitlab-policies/js6');
      expect(link.text()).toBe('gitlab-policies/js6');
    });

    it('renders the policy summary as a link for the file field', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      const link = findLink(findFileSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(
        '/path/to/project/-/blob/main/pipeline_execution_jobs.yml',
      );
      expect(link.text()).toBe('pipeline_execution_jobs.yml');
    });
  });

  describe('configuration', () => {
    it('renders default configuration row if there is no configuration in policy', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionPolicy },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });

    it('renders configuration row when there is a configuration', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionWithConfigurationPolicy },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });
  });
});
