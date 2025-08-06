import { shallowMount } from '@vue/test-utils';
import JiraVerificationFields from 'ee/integrations/edit/components/jira_verification_fields.vue';

describe('JiraVerificationFields', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(JiraVerificationFields, {
      propsData: {
        initialJiraCheckEnabled: false,
        initialJiraExistsCheckEnabled: false,
        initialJiraAssigneeCheckEnabled: false,
        initialJiraStatusCheckEnabled: false,
        initialJiraAllowedStatusesAsString: '',
        showJiraIssuesIntegration: true,
        ...props,
      },
      mocks: {
        $store: {
          getters: {
            isInheriting: false,
          },
        },
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the main checkbox', () => {
      const checkbox = wrapper.findComponent('[data-testid="jira-check-enabled-checkbox"]');

      expect(checkbox.exists()).toBe(true);
      expect(checkbox.attributes('disabled')).toBeUndefined();
    });

    it('does not render the nested checkboxes when main checkbox is not checked', () => {
      expect(
        wrapper.findComponent('[data-testid="jira-exists-check-enabled-checkbox"]').exists(),
      ).toBe(false);
    });
  });

  describe('when main checkbox is checked', () => {
    beforeEach(() => {
      createComponent({ initialJiraCheckEnabled: true });
    });

    it('renders all nested checkboxes', () => {
      expect(
        wrapper.findComponent('[data-testid="jira-exists-check-enabled-checkbox"]').exists(),
      ).toBe(true);
      expect(
        wrapper.findComponent('[data-testid="jira-assignee-check-enabled-checkbox"]').exists(),
      ).toBe(true);
      expect(
        wrapper.findComponent('[data-testid="jira-status-check-enabled-checkbox"]').exists(),
      ).toBe(true);
    });

    it('does not render the allowed statuses textarea when status check is not enabled', () => {
      expect(wrapper.findComponent('[data-testid="jira-allowed-statuses"]').exists()).toBe(false);
    });
  });

  describe('when status check is enabled', () => {
    beforeEach(() => {
      createComponent({
        initialJiraCheckEnabled: true,
        initialJiraStatusCheckEnabled: true,
        initialJiraAllowedStatusesAsString: 'Ready,In Progress',
      });
    });

    it('renders the allowed statuses textarea', () => {
      const textarea = wrapper.find('[data-testid="jira-allowed-statuses-field"]');

      expect(textarea.exists()).toBe(true);
      expect(textarea.attributes('placeholder')).toBe('Ready, In Progress, Review');
      // In Vue 3, we should check the modelValue prop or modify our approach
      expect(wrapper.vm.jiraAllowedStatusesAsString).toBe('Ready,In Progress');
    });
  });

  describe('when isInheriting is true', () => {
    beforeEach(() => {
      wrapper = shallowMount(JiraVerificationFields, {
        propsData: {
          initialJiraCheckEnabled: true,
          initialJiraStatusCheckEnabled: true,
          showJiraIssuesIntegration: true,
        },
        mocks: {
          $store: {
            getters: {
              isInheriting: true,
            },
          },
        },
      });
    });

    it('disables all inputs', () => {
      const mainCheckbox = wrapper.findComponent('[data-testid="jira-check-enabled-checkbox"]');
      const statusCheckbox = wrapper.findComponent(
        '[data-testid="jira-status-check-enabled-checkbox"]',
      );

      // In Vue 3, disabled is an attribute, not a prop
      expect(mainCheckbox.attributes('disabled')).toBeDefined();
      expect(statusCheckbox.attributes('disabled')).toBeDefined();
    });
  });

  describe('hidden input fields', () => {
    beforeEach(() => {
      createComponent({
        initialJiraCheckEnabled: true,
        initialJiraExistsCheckEnabled: true,
        initialJiraAssigneeCheckEnabled: false,
        initialJiraStatusCheckEnabled: true,
        initialJiraAllowedStatusesAsString: 'Ready,In Progress',
      });
    });

    it('has hidden input fields with the correct values', () => {
      const hiddenFields = wrapper.findAll('input[type="hidden"]');

      expect(hiddenFields).toHaveLength(4);

      // In Vue 3, we need to make sure the component data is properly synced with the DOM
      // before checking attributes

      const jiraCheckEnabledInput = wrapper.find('input[name="service[jira_check_enabled]"]');
      expect(jiraCheckEnabledInput.attributes('value')).toBe('true');

      const jiraExistsCheckEnabledInput = wrapper.find(
        'input[name="service[jira_exists_check_enabled]"]',
      );
      expect(jiraExistsCheckEnabledInput.attributes('value')).toBe('true');

      const jiraAssigneeCheckEnabledInput = wrapper.find(
        'input[name="service[jira_assignee_check_enabled]"]',
      );
      expect(jiraAssigneeCheckEnabledInput.attributes('value')).toBe('false');

      const jiraStatusCheckEnabledInput = wrapper.find(
        'input[name="service[jira_status_check_enabled]"]',
      );
      expect(jiraStatusCheckEnabledInput.attributes('value')).toBe('true');
    });
  });
});
