import { shallowMount } from '@vue/test-utils';
import JiraVerificationSection from 'ee/integrations/edit/components/sections/jira_verification.vue';
import JiraVerificationFields from 'ee/integrations/edit/components/jira_verification_fields.vue';

describe('JiraVerificationSection', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(JiraVerificationSection, {
      mocks: {
        $store: {
          getters: {
            currentKey: 'test-key',
            propsSource: {
              jiraVerificationProps: {
                initialJiraCheckEnabled: false,
                initialJiraExistsCheckEnabled: false,
                initialJiraAssigneeCheckEnabled: false,
                initialJiraStatusCheckEnabled: false,
                initialJiraAllowedStatusesAsString: '',
                showJiraIssuesIntegration: false,
              },
            },
          },
        },
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the JiraVerificationFields component with the correct props', () => {
      const jiraVerificationFields = wrapper.findComponent(JiraVerificationFields);

      expect(jiraVerificationFields.exists()).toBe(true);
      expect(jiraVerificationFields.props()).toEqual({
        initialJiraCheckEnabled: false,
        initialJiraExistsCheckEnabled: false,
        initialJiraAssigneeCheckEnabled: false,
        initialJiraStatusCheckEnabled: false,
        initialJiraAllowedStatusesAsString: '',
        showJiraIssuesIntegration: false,
      });
      expect(jiraVerificationFields.vm.$vnode.key).toBe('test-key-jira-verification-fields');
    });
  });
});
