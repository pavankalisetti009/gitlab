import RootCauseAnalysisButton from 'ee/ci/job_details/components/root_cause_analysis_button.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Root cause analysis button', () => {
  let wrapper;

  const defaultProps = {
    jobFailed: true,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(RootCauseAnalysisButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        aiRootCauseAnalysisAvailable: true,
        duoFeaturesEnabled: true,
        glFeatures: {
          aiBuildFailureCause: true,
          rootCauseAnalysisDuo: true,
        },
        glAbilities: {
          troubleshootJobWithAi: true,
        },
        jobGid: 'gid://gitlab/Ci::Build/123',
      },
    });
  };

  const findTroubleshootButton = () => wrapper.findByTestId('rca-duo-button');

  it('should display the Troubleshoot button', () => {
    createComponent();

    expect(findTroubleshootButton().exists()).toBe(true);
  });

  it('should not display the Troubleshoot button when no failure is detected', () => {
    createComponent({ jobFailed: false });

    expect(findTroubleshootButton().exists()).toBe(false);
  });
});
