import { GlButtonGroup, GlButton, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogNodeField from 'ee/ai/catalog/components/ai_catalog_node_field.vue';

describe('AiCatalogNodeField', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogNodeField, {
      propsData: {
        selected: {},
        ...props,
      },
    });
  };

  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findTypeLabelButton = () => findButtons().at(0);
  const findPrimaryButton = () => findButtons().at(1);
  const findGripButton = () => findButtons().at(2);
  const findIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders a GlButtonGroup', () => {
      const buttonGroup = findButtonGroup();
      expect(buttonGroup.exists()).toBe(true);
    });

    it('renders three buttons', () => {
      expect(findButtons()).toHaveLength(3);
    });

    it('renders the agent button as disabled with correct text', () => {
      const agentButton = findTypeLabelButton();
      expect(agentButton.exists()).toBe(true);
      expect(agentButton.props('disabled')).toBe(true);
      expect(agentButton.classes()).toContain('!gl-flex-none');
      expect(agentButton.text()).toBe('Agent');
    });

    it('renders the primary button with default text', () => {
      const primaryButton = findPrimaryButton();
      expect(primaryButton.exists()).toBe(true);
      expect(primaryButton.props('disabled')).toBe(false);
      expect(primaryButton.text()).toBe('Draft node');
    });

    it('renders the grip button as disabled with grip icon', () => {
      const gripButton = findGripButton();
      const icon = findIcon();

      expect(gripButton.exists()).toBe(true);
      expect(gripButton.props('disabled')).toBe(true);
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('grip');
    });
  });

  describe('events', () => {
    it('emits primary event when primary button is clicked', async () => {
      const primaryButton = findPrimaryButton();

      await primaryButton.vm.$emit('click');

      expect(wrapper.emitted('primary')).toHaveLength(1);
      expect(wrapper.emitted('primary')[0]).toEqual([]);
    });
  });

  describe('slots', () => {
    it('renders default slot content in agent button', () => {
      createComponent();
      const agentButton = findTypeLabelButton();
      expect(agentButton.text()).toBe('Agent');
    });

    it('renders default slot content in primary button', () => {
      createComponent();
      const primaryButton = findPrimaryButton();
      expect(primaryButton.text()).toBe('Draft node');
    });

    it('allows custom slot content to override default text', () => {
      wrapper = shallowMountExtended(AiCatalogNodeField, {
        propsData: { selected: {} },
        slots: {
          'button-content': 'Custom Button Text',
        },
      });

      // Both buttons should show the custom slot content
      const buttons = findButtons();
      expect(buttons.at(0).text()).toBe('Custom Button Text');
      expect(buttons.at(1).text()).toBe('Custom Button Text');
    });
  });

  describe('button states and interactions', () => {
    it('updates primary button text when selected prop changes', async () => {
      createComponent({ selected: {} });
      expect(findPrimaryButton().text()).toBe('Draft node');

      await wrapper.setProps({ selected: { text: 'New Agent' } });
      expect(findPrimaryButton().text()).toBe('New Agent');
    });
  });

  describe('component structure', () => {
    it('maintains correct button order', () => {
      const buttons = findButtons();

      // First button: Agent (disabled)
      expect(buttons.at(0).props('disabled')).toBe(true);
      expect(buttons.at(0).text()).toBe('Agent');

      // Second button: Primary action (enabled)
      expect(buttons.at(1).props('disabled')).toBe(false);
      expect(buttons.at(1).text()).toBe('Draft node');

      // Third button: Grip (disabled, with icon)
      expect(buttons.at(2).props('disabled')).toBe(true);
      expect(buttons.at(2).findComponent(GlIcon).exists()).toBe(true);
    });
  });
});
