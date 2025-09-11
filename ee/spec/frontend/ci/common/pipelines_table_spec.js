import Vue from 'vue';
import VueApollo from 'vue-apollo';
// fixture located in spec/frontend/fixtures/pipelines.rb
import fixture from 'test_fixtures/pipelines/pipelines.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PipelinesTable from '~/ci/common/pipelines_table.vue';
import { PIPELINE_ID_KEY } from '~/ci/constants';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';

Vue.use(VueApollo);

describe('EE - Pipelines Table', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: '/my-project/',
    useFailedJobsWidget: false,
    glFeatures: {
      aiDuoAgentFixPipelineButton: true,
    },
  };

  const { pipelines } = fixture;
  const [firstPipeline] = pipelines;

  const defaultProps = {
    pipelines,
    pipelineIdType: PIPELINE_ID_KEY,
  };

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = mountExtended(PipelinesTable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        PipelineOperations: false,
        DuoWorkflowAction: true,
        ...stubs,
      },
      apolloProvider: createMockApollo(),
    });
  };

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('Duo Workflow Action', () => {
    const failedPipelineWithMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/123',
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/123',
      },
    };

    const failedPipelineWithoutMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/456',
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
    };

    const successfulPipelineWithMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/789',
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'success',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/456',
      },
    };

    beforeEach(() => {
      window.gon = { gitlab_url: 'https://gitlab.com' };
    });

    describe('when pipeline has failed and has associated merge request', () => {
      beforeEach(() => {
        gon.api_version = 'v4';
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
        });
      });

      it('renders DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(true);
      });

      it('passes correct props to DuoWorkflowAction', () => {
        expect(findDuoWorkflowAction().props()).toMatchObject({
          duoWorkflowInvokePath: '/api/v4/ai/duo_workflows/workflows',
          projectId: failedPipelineWithMR.project.id,
          projectPath: 'frontend-fixtures/pipelines-project',
          goal: 'https://gitlab.com/project/-/pipelines/123',
          hoverMessage: 'Fix pipeline with Duo',
          workflowDefinition: 'fix_pipeline/experimental',
          size: 'medium',
          agentPrivileges: [1, 2, 3, 5],
          sourceBranch: 'master',
          additionalContext: [
            {
              Category: 'agent_user_environment',
              Content: JSON.stringify({
                merge_request_url: 'https://gitlab.com/project/-/merge_requests/123',
                source_branch: 'master',
              }),
              Metadata: '{}',
            },
          ],
        });
      });
    });

    describe('when pipeline has failed but has no associated merge request', () => {
      beforeEach(() => {
        createComponent({
          props: { pipelines: [failedPipelineWithoutMR] },
        });
      });

      it('does not render DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });

    describe('when merge_request property is null', () => {
      it('does not render DuoWorkflowAction component', () => {
        const failedPipelineWithNullMR = {
          ...failedPipelineWithoutMR,
          merge_request: null,
        };

        createComponent({
          props: { pipelines: [failedPipelineWithNullMR] },
        });

        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });

    describe('when pipeline is successful', () => {
      beforeEach(() => {
        createComponent({
          props: { pipelines: [successfulPipelineWithMR] },
        });
      });

      it('does not render DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });

    describe('when aiDuoAgentFixPipelineButton feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
          provide: {
            glFeatures: {
              aiDuoAgentFixPipelineButton: false,
            },
          },
        });
      });

      it('does not render DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });

    describe('pipeline path and additional context handling', () => {
      it('correctly constructs pipeline URL when gon.gitlab_url is set', () => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
        });

        expect(findDuoWorkflowAction().props('goal')).toBe(
          'https://gitlab.com/project/-/pipelines/123',
        );
      });

      it('includes merge request URL in additional context when available', () => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
        });

        const additionalContext = findDuoWorkflowAction().props('additionalContext');
        expect(additionalContext).toHaveLength(1);
        expect(additionalContext[0]).toEqual({
          Category: 'agent_user_environment',
          Content: JSON.stringify({
            merge_request_url: 'https://gitlab.com/project/-/merge_requests/123',
            source_branch: 'master',
          }),
          Metadata: '{}',
        });
      });
    });

    describe('multiple pipelines', () => {
      it('renders DuoWorkflowAction only for failed pipelines with MRs', () => {
        createComponent({
          props: {
            pipelines: [
              failedPipelineWithMR,
              failedPipelineWithMR,
              successfulPipelineWithMR,
              failedPipelineWithoutMR,
            ],
          },
        });

        expect(wrapper.findAllComponents(DuoWorkflowAction)).toHaveLength(2);
      });
    });
  });
});
