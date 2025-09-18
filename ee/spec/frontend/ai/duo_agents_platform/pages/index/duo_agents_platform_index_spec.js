import { shallowMount } from '@vue/test-utils';
import { GlExperimentBadge, GlLoadingIcon } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';

import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';

import waitForPromises from 'helpers/wait_for_promises';

import { mockAgentFlowsResponse } from '../../../mocks';

jest.mock('~/alert');

describe('AgentsPlatformIndex', () => {
  let wrapper;
  const mockRefetch = jest.fn().mockResolvedValue({ data: { workflows: [] } });

  const defaultProps = {
    isLoadingWorkflows: false,
    workflows: mockAgentFlowsResponse.data.project.duoWorkflowWorkflows.edges.map(
      (edge) => edge.node,
    ),
    workflowsPageInfo: { startCursor: 'asdf', endCursor: 'asdf' },
    workflowQuery: {
      loading: false,
      refetch: mockRefetch,
      variables: { projectPath: 'hello!' },
    },
  };

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMount(AgentsPlatformIndex, {
      propsData: { ...defaultProps, ...props },
      provide: {
        isSidePanelView: false,
        ...provide,
      },
    });

    return waitForPromises();
  };

  const findWorkflowsList = () => wrapper.findComponent(AgentFlowList);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNewAgentFlowButton = () => wrapper.find('[data-testid="new-agent-flow-button"]');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);

  describe('when not in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: false } });
    });

    it('loads the page heading and experiment badge', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Agent sessions');

      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });

    it('renders the new agent flow button', () => {
      expect(findNewAgentFlowButton().exists()).toBe(true);
    });

    it('applies no margin top class to page heading', () => {
      expect(findPageHeading().classes()).not.toContain('gl-mt-0');
    });
  });

  describe('when in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: true } });
    });

    it('does not render the page heading', () => {
      expect(findPageHeading().exists()).toBe(false);
    });

    it('does not render the new agent flow button', () => {
      expect(findNewAgentFlowButton().exists()).toBe(false);
    });
  });

  describe('when loading the queries', () => {
    beforeEach(() => {
      createWrapper({ props: { isLoadingWorkflows: true } });
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the workflow list', () => {
      expect(findWorkflowsList().exists()).toBe(false);
    });
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the workflows list component', () => {
      expect(findWorkflowsList().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when next page is requested', () => {
      it('calls refetch with correct parameters', () => {
        findWorkflowsList().vm.$emit('next-page');

        expect(mockRefetch).toHaveBeenCalledWith({
          projectPath: 'hello!',
          after: 'asdf',
          last: null,
          before: null,
          first: 20,
        });
      });
    });

    describe('when previous page is requested', () => {
      it('calls refetch with correct parameters', () => {
        findWorkflowsList().vm.$emit('prev-page');

        expect(mockRefetch).toHaveBeenCalledWith({
          projectPath: 'hello!',
          after: null,
          last: 20,
          before: 'asdf',
          first: null,
        });
      });
    });
  });
});
