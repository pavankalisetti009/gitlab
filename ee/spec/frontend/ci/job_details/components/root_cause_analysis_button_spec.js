import { GlButton } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import RootCauseAnalysisButton from 'ee/ci/job_details/components/root_cause_analysis_button.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('ee/ai/utils', () => ({
  sendDuoChatCommand: jest.fn(),
}));

describe('Root cause analysis button', () => {
  let wrapper;

  const defaultProps = {
    jobFailed: true,
  };

  const jobGid = 'gid://gitlab/Ci::Build/123';

  const createComponent = (props) => {
    wrapper = shallowMountExtended(RootCauseAnalysisButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glAbilities: {
          troubleshootJobWithAi: true,
        },
        jobGid,
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

  it('sends a call to the sendDuoChatCommand utility function', () => {
    createComponent();

    wrapper.findComponent(GlButton).vm.$emit('click');

    expect(sendDuoChatCommand).toHaveBeenCalledWith({
      question: '/troubleshoot',
      resourceId: jobGid,
    });
  });
});
