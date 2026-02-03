import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';
import GroupItemConsumerDropdown from 'ee/ai/duo_agents_platform/components/catalog/group_item_consumer_dropdown.vue';
import AddAgentWarning from 'ee/ai/duo_agents_platform/components/catalog/add_agent_warning.vue';
import AddFlowWarning from 'ee/ai/duo_agents_platform/components/catalog/add_flow_warning.vue';
import AddThirdPartyFlowWarning from 'ee/ai/duo_agents_platform/components/catalog/add_third_party_flow_warning.vue';
import {
  mockAgentItemConsumer,
  mockFlowItemConsumer,
  mockThirdPartyFlowItemConsumer,
  mockFlow,
  mockBaseItemConsumer,
  mockBaseFlow,
} from 'ee_jest/ai/catalog/mock_data';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';
import { stubComponent } from 'helpers/stub_component';

describe('AddProjectItemConsumerModal', () => {
  let wrapper;

  const modalStub = { hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const defaultProps = {
    itemTypes: ['FLOW'],
    modalId: 'add-flow-to-project-modal',
    modalTexts: {
      title: 'Enable flow from group',
      dropdownTexts: {},
    },
  };

  const createComponent = ({ props = {}, aiFlowTriggerPipelineHooks = true } = {}) => {
    wrapper = shallowMount(AddProjectItemConsumerModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: { glFeatures: { aiFlowTriggerPipelineHooks } },
      stubs: {
        GlModal: GlModalStub,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findGroupItemConsumerDropdown = () => wrapper.findComponent(GroupItemConsumerDropdown);
  const findFormCheckboxGroup = () => wrapper.findComponent(GlFormCheckboxGroup);
  const findFormCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);

  beforeEach(() => {
    createComponent();
    findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
  });

  describe('component rendering', () => {
    it('renders modal', () => {
      expect(findModal().props()).toMatchObject({
        title: 'Enable flow in your project',
        actionPrimary: {
          text: 'Enable',
          attributes: {
            variant: 'confirm',
            type: 'submit',
          },
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
    });

    it('renders form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders group item consumer dropdown', () => {
      expect(findGroupItemConsumerDropdown().exists()).toBe(true);
    });

    describe('useRootGroupFlows prop', () => {
      it('passes useRootGroupFlows=true to dropdown when prop is true', () => {
        createComponent({ props: { useRootGroupFlows: true } });

        expect(findGroupItemConsumerDropdown().props('useRootGroupFlows')).toBe(true);
      });

      it('passes useRootGroupFlows=false to dropdown when prop is false', () => {
        createComponent({ props: { useRootGroupFlows: false } });

        expect(findGroupItemConsumerDropdown().props('useRootGroupFlows')).toBe(false);
      });

      it('defaults useRootGroupFlows to false', () => {
        createComponent();

        expect(findGroupItemConsumerDropdown().props('useRootGroupFlows')).toBe(false);
      });
    });

    it('does not render pre-selected trigger type checkboxes by default', () => {
      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer,pipeline_hooks',
      );

      const checkboxes = findFormCheckboxes();
      expect(checkboxes).toHaveLength(4);
      expect(checkboxes.at(0).props('value')).toBe('mention');
      expect(checkboxes.at(1).props('value')).toBe('assign');
      expect(checkboxes.at(2).props('value')).toBe('assign_reviewer');
      expect(checkboxes.at(3).props('value')).toBe('pipeline_hooks');
    });

    describe('when the aiFlowTriggerPipelineHooks feature flag is disabled', () => {
      it('excludes the pipeline_hooks checkbox', () => {
        createComponent({
          aiFlowTriggerPipelineHooks: false,
          props: { item: mockFlow, showAddToGroup: false },
        });

        expect(findFormCheckboxGroup().attributes('checked')).not.toContain('pipeline_hooks');
        expect(findFormCheckboxes()).toHaveLength(3);
      });
    });
  });

  describe('form submission', () => {
    const mockInput = {
      preventDefault: jest.fn(),
    };

    beforeEach(async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
      findFormCheckboxGroup().vm.$emit('input', ['mention']);

      findForm().vm.$emit('submit', mockInput);
    });

    it('hides the modal', () => {
      expect(modalStub.hide).toHaveBeenCalled();
    });

    it('emits submit event when form is submitted', () => {
      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        itemId: mockFlowItemConsumer.item.id,
        itemName: mockFlowItemConsumer.item.name,
        parentItemConsumerId: mockFlowItemConsumer.id,
        target: { projectId: null },
        triggerTypes: ['mention'],
      });
    });
  });

  describe('when the modal is hidden', () => {
    beforeEach(async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
      findFormCheckboxGroup().vm.$emit('input', ['mention']);

      findModal().vm.$emit('hidden');
    });

    it('resets the form', async () => {
      expect(findGroupItemConsumerDropdown().props('value')).toBeNull();

      // Need to set a flow type consumer again to check the trigger types are reset
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);

      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer,pipeline_hooks',
      );
    });
  });

  describe('when form is submitted and modal is hidden', () => {
    it('only resets the form once after modal is hidden', async () => {
      const resetFormSpy = jest.spyOn(wrapper.vm, 'resetForm');

      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
      await findFormCheckboxGroup().vm.$emit('input', ['assign']);

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      // Before hidden event, form should still have the selected values
      expect(findFormCheckboxGroup().attributes('checked')).toEqual('assign');

      findModal().vm.$emit('hidden');
      await nextTick();

      // After hidden event, form should be reset
      expect(resetFormSpy).toHaveBeenCalledTimes(1);
      expect(findGroupItemConsumerDropdown().props('value')).toBeNull();

      // Need to set a flow type consumer again to check the trigger types are reset
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer,pipeline_hooks',
      );
    });
  });

  describe('when the selected item is an agent', () => {
    it('does not render trigger checkboxes', async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockAgentItemConsumer);
      expect(findFormCheckboxGroup().exists()).toBe(false);
      expect(findFormCheckboxes()).toHaveLength(0);
    });

    it('does not pass triggerTypes on form submission', () => {
      findGroupItemConsumerDropdown().vm.$emit('input', mockAgentItemConsumer);

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        itemId: mockAgentItemConsumer.item.id,
        itemName: mockAgentItemConsumer.item.name,
        parentItemConsumerId: mockAgentItemConsumer.id,
        target: { projectId: null },
      });
    });
  });

  describe('when the selected item is a third party flow', () => {
    it('renders trigger checkboxes', async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockThirdPartyFlowItemConsumer);
      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer,pipeline_hooks',
      );

      const checkboxes = findFormCheckboxes();
      expect(checkboxes).toHaveLength(4);
      expect(checkboxes.at(0).props('value')).toBe('mention');
      expect(checkboxes.at(1).props('value')).toBe('assign');
      expect(checkboxes.at(2).props('value')).toBe('assign_reviewer');
      expect(checkboxes.at(3).props('value')).toBe('pipeline_hooks');
    });

    it('passes triggerTypes on form submission', async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockThirdPartyFlowItemConsumer);

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        itemId: mockThirdPartyFlowItemConsumer.item.id,
        itemName: mockThirdPartyFlowItemConsumer.item.name,
        parentItemConsumerId: mockThirdPartyFlowItemConsumer.id,
        target: { projectId: null },
        triggerTypes: ['mention', 'assign', 'assign_reviewer', 'pipeline_hooks'],
      });
    });
  });

  describe('when item is passed', () => {
    describe('at project level', () => {
      beforeEach(() => {
        createComponent({
          props: { item: mockFlow, showAddToGroup: false },
        });
      });

      it('does not display dropdown', () => {
        expect(findGroupItemConsumerDropdown().exists()).toBe(false);

        findForm().vm.$emit('submit', { preventDefault: jest.fn() });

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toEqual({
          target: { projectId: 'gid://gitlab/Project/1' },
          triggerTypes: ['mention', 'assign', 'assign_reviewer', 'pipeline_hooks'],
        });
      });
    });

    describe('at group level', () => {
      beforeEach(() => {
        createComponent({
          props: { item: mockFlow, showAddToGroup: true },
        });
      });

      it('does not display dropdown', () => {
        expect(findGroupItemConsumerDropdown().exists()).toBe(false);

        findForm().vm.$emit('submit', { preventDefault: jest.fn() });

        expect(wrapper.emitted('submit')).toHaveLength(1);
        expect(wrapper.emitted('submit')[0][0]).toEqual({
          target: { groupId: 'gid://gitlab/Group/1' },
          triggerTypes: ['mention', 'assign', 'assign_reviewer', 'pipeline_hooks'],
        });
      });
    });
  });

  describe.each`
    selectedItemType                    | warningComponent
    ${AI_CATALOG_TYPE_AGENT}            | ${AddAgentWarning}
    ${AI_CATALOG_TYPE_FLOW}             | ${AddFlowWarning}
    ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${AddThirdPartyFlowWarning}
  `(
    'when the selected item type is $selectedItemType',
    ({ selectedItemType, warningComponent }) => {
      it('renders the correct warning component', async () => {
        const itemConsumer = {
          item: {
            itemType: selectedItemType,
          },
        };
        await findGroupItemConsumerDropdown().vm.$emit('input', itemConsumer);
        expect(wrapper.findComponent(warningComponent).exists()).toBe(true);
      });
    },
  );

  describe('when the selected item is a foundational flow', () => {
    const mockFoundationalFlowItemConsumer = {
      ...mockBaseItemConsumer,
      item: {
        ...mockBaseFlow,
        foundational: true,
      },
    };

    it('does not render trigger checkboxes', async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFoundationalFlowItemConsumer);
      expect(findFormCheckboxGroup().exists()).toBe(false);
      expect(findFormCheckboxes()).toHaveLength(0);
    });

    it('does not pass triggerTypes on form submission', async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFoundationalFlowItemConsumer);

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        itemId: mockFoundationalFlowItemConsumer.item.id,
        itemName: mockFoundationalFlowItemConsumer.item.name,
        parentItemConsumerId: mockFoundationalFlowItemConsumer.id,
        target: { projectId: null },
      });
    });
  });

  describe('when item prop is a foundational flow', () => {
    const mockFoundationalFlow = {
      ...mockFlow,
      foundational: true,
    };

    beforeEach(() => {
      createComponent({
        props: { item: mockFoundationalFlow, showAddToGroup: false },
      });
    });

    it('does not render trigger checkboxes', () => {
      expect(findFormCheckboxGroup().exists()).toBe(false);
      expect(findFormCheckboxes()).toHaveLength(0);
    });

    it('does not pass triggerTypes on form submission', () => {
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        target: { projectId: 'gid://gitlab/Project/1' },
      });
    });
  });
});
