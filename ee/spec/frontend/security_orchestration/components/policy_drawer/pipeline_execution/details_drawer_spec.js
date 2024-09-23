import { GlLink } from '@gitlab/ui';
import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { mockProjectPipelineExecutionPolicy } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

describe('PipelineExecutionDrawer', () => {
  let wrapper;

  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findSummaryHeader = () => wrapper.findByTestId('summary-header');
  const findSummaryFields = () => wrapper.findAllByTestId('summary-fields');
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findLink = (parent) => parent.findComponent(GlLink);

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(PipelineExecutionDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
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

  describe('summary', () => {
    it('renders paragraph policy summary as text', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      expect(findSummary().exists()).toBe(true);
      expect(findSummaryFields()).toHaveLength(1);
      const text = trimText(findSummaryFields().at(0).text());
      expect(text).toContain('Project : gitlab-policies/js6');
      expect(text).toContain('Reference : main');
      expect(text).toContain('Path : test_path');
      expect(findSummaryHeader().text()).toBe('Enforce the following pipeline execution policy:');
    });

    it('renders the policy summary as a link for the project field', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      const link = findLink(findSummaryFields().at(0));
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/gitlab-policies/js6');
      expect(link.text()).toBe('gitlab-policies/js6');
    });
  });
});
