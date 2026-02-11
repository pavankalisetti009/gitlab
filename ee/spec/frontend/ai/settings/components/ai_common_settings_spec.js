import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses } from '../../mocks';

describe('AiCommonSettings', () => {
  let wrapper;
  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCommonSettings, {
      propsData: {
        hasParentFormChanged: false,
        ...props,
      },
      provide: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: true,
        initialDuoRemoteFlowsAvailability: false,
        initialDuoSastFpDetectionAvailability: false,
        foundationalAgentsDefaultEnabled: true,
        initialFoundationalAgentsStatuses: mockAgentStatuses,
        initialDuoFoundationalFlowsAvailability: false,
        initialDuoWorkflowsDefaultImageRegistry: '',
        initialSelectedFoundationalFlowIds: [],
        initialDuoAgentPlatformEnabled: true,
        initialNamespaceAccessRules: [],
        initialMinimumAccessLevelExecuteAsync: 30,
        initialMinimumAccessLevelExecuteSync: 10,
        onGeneralSettingsPage: false,
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
        ...provide,
      },
      stubs: {
        GlSprintf: {
          template: `
            <span>
              <slot name="link" v-bind="{ content: $attrs.message }">
              </slot>
            </span>
          `,
          components: {
            GlLink,
          },
        },
      },
      slots: {
        'ai-common-settings-top': '<div data-testid="top-slot-content">Top slot content</div>',
        'ai-common-settings-bottom':
          '<div data-testid="bottom-slot-content">Bottom slot content</div>',
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findGeneralSettingsDescriptionText = () =>
    wrapper.findByTestId('general-settings-subtitle');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findForm = () => wrapper.findComponent(AiCommonSettingsForm);
  const findTopSettingsSlot = () => wrapper.findByTestId('top-slot-content');
  const findBottomSettingsSlot = () => wrapper.findByTestId('bottom-slot-content');

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the AiCommonSettingsForm component', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('emits submit event with correct data when form is submitted via AiCommonSettingsForm component', async () => {
    await findForm().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    await findForm().vm.$emit('experiment-checkbox-changed', true);
    await findForm().vm.$emit('duo-core-checkbox-changed', true);
    await findForm().vm.$emit('duo-flow-checkbox-changed', true);
    await findForm().vm.$emit('duo-foundational-agents-changed', true);
    await findForm().vm.$emit('duo-foundational-flows-checkbox-changed', true);
    await findForm().vm.$emit('change-selected-flow-ids', [1, 2]);
    await findForm().vm.$emit('duo-agent-platform-enabled-changed', false);
    await findForm().vm.$emit('namespace-access-rules-changed', [
      { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
    ]);
    await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);
    await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);
    await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');
    findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
    const emittedData = wrapper.emitted('submit')[0][0];
    expect(emittedData).toEqual({
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      experimentFeaturesEnabled: true,
      duoCoreFeaturesEnabled: true,
      promptCacheEnabled: true,
      duoRemoteFlowsAvailability: true,
      duoFoundationalFlowsAvailability: true,
      foundationalAgentsEnabled: true,
      selectedFoundationalFlowIds: [1, 2],
      foundationalAgentsStatuses: mockAgentStatuses,
      duoAgentPlatformEnabled: false,
      namespaceAccessRules: [
        { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
      ],
      minimumAccessLevelExecuteAsync: 40,
      minimumAccessLevelExecuteSync: 20,
      duoWorkflowsDefaultImageRegistry: 'registry.example.com',
    });
  });

  it('does not include namespaceAccessRules in submit event when they have not been changed', async () => {
    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });

    const emittedData = wrapper.emitted('submit')[0][0];

    expect(emittedData).not.toHaveProperty('namespaceAccessRules');
  });

  it('includes namespaceAccessRules when a change has been made', async () => {
    await findForm().vm.$emit('namespace-access-rules-changed', [
      { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
    ]);

    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });

    const emittedData = wrapper.emitted('submit')[0][0];

    expect(emittedData).toHaveProperty('namespaceAccessRules');
  });

  describe('when on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
    });

    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes props to settings-block component', () => {
      expect(findSettingsBlock().props()).toEqual({
        expanded: false,
        id: 'js-gitlab-duo-settings',
        title: 'GitLab Duo features',
      });
    });

    it('renders the settings block description text', () => {
      expect(findGeneralSettingsDescriptionText().text()).toContain(
        'Configure AI-native GitLab Duo features',
      );
    });

    it('renders ai-common-settings slots', () => {
      expect(findTopSettingsSlot().exists()).toBe(true);
      expect(findBottomSettingsSlot().exists()).toBe(true);
    });
  });

  describe('when not on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: false } });
    });

    it('renders PageHeading component', () => {
      expect(findPageHeading().exists()).toBe(true);
    });

    it('renders correct title in PageHeading', () => {
      expect(findPageHeading().props('heading')).toBe('Configuration');
    });

    it('renders correct subtitle in PageHeading', () => {
      expect(wrapper.findByTestId('configuration-page-subtitle').exists()).toBe(true);
    });

    it('renders ai-common-settings slots', () => {
      expect(findTopSettingsSlot().exists()).toBe(true);
      expect(findBottomSettingsSlot().exists()).toBe(true);
    });

    it('passes initialNamespaceAccessRules prop to form', () => {
      expect(findForm().props('initialNamespaceAccessRules')).toEqual([]);
    });
  });

  describe('foundational agents', () => {
    it('passes foundational-agents-enabled value to the form', () => {
      expect(findForm().props('foundationalAgentsEnabled')).toEqual(true);
    });

    it('includes foundational agents enabled in submit event', async () => {
      await findForm().vm.$emit('duo-foundational-agents-changed', false);
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const [[{ foundationalAgentsEnabled }]] = wrapper.emitted('submit');
      expect(foundationalAgentsEnabled).toEqual(false);
    });

    describe('per agent settings', () => {
      it('passes foundational-agents-statuses to the form', () => {
        expect(findForm().props('foundationalAgentsStatuses')).toEqual(mockAgentStatuses);
      });

      it('includes foundational agents statuses in submit event', async () => {
        const updatedStatuses = [
          { reference: 'security-analyst', name: 'Security Analyst', enabled: false },
          { reference: 'code-reviewer', name: 'Code Reviewer', enabled: true },
          { reference: 'test-agent', name: 'Test Agent', enabled: null },
        ];

        await findForm().vm.$emit('duo-foundational-agents-statuses-change', updatedStatuses);
        findForm().vm.$emit('submit', { preventDefault: jest.fn() });

        const [[{ foundationalAgentsStatuses }]] = wrapper.emitted('submit');
        expect(foundationalAgentsStatuses).toEqual(updatedStatuses);
      });
    });
  });

  describe('minimum access level permissions', () => {
    it('updates internal state when form emits minimum-access-level-execute-async-changed', async () => {
      expect(wrapper.vm.minimumAccessLevelExecuteAsync).toBe(30);

      await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);

      expect(wrapper.vm.minimumAccessLevelExecuteAsync).toBe(40);
    });

    it('updates internal state when form emits minimum-access-level-execute-sync-changed', async () => {
      expect(wrapper.vm.minimumAccessLevelExecuteSync).toBe(10);

      await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);

      expect(wrapper.vm.minimumAccessLevelExecuteSync).toBe(20);
    });

    it('includes minimum access levels in submit event', async () => {
      await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);
      await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      const emittedData = wrapper.emitted('submit')[0][0];
      expect(emittedData).toMatchObject({
        minimumAccessLevelExecuteAsync: 40,
        minimumAccessLevelExecuteSync: 20,
      });
    });
  });

  describe('duo workflows default image registry', () => {
    it('updates internal state when form emits change-default-image-registry', async () => {
      expect(wrapper.vm.duoWorkflowsDefaultImageRegistry).toBe('');

      await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(wrapper.vm.duoWorkflowsDefaultImageRegistry).toBe('registry.example.com');
    });

    it('includes duo workflows default image registry in submit event', async () => {
      await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      const emittedData = wrapper.emitted('submit')[0][0];
      expect(emittedData).toMatchObject({
        duoWorkflowsDefaultImageRegistry: 'registry.example.com',
      });
    });
  });
});
