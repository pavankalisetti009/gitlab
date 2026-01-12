import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import DuoWorkflowSettingsForm from 'ee/ai/settings/components/duo_workflow_settings_form.vue';
import { PROTECTION_LEVEL_OPTIONS } from 'ee/ai/settings/constants';

describe('DuoWorkflowSettingsForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(DuoWorkflowSettingsForm, {
      propsData: {
        isMcpEnabled: false,
        showMcp: true,
        promptInjectionProtectionLevel: 'interrupt',
        showProtection: true,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
        GlFormRadio,
        GlFormRadioGroup,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findRadios = () => wrapper.findAllComponents(GlFormRadio);

  describe('MCP Section', () => {
    it('renders the MCP section title correctly', () => {
      const titles = wrapper.findAll('h5');
      expect(titles.at(0).text()).toContain('External MCP tools');
    });

    it('renders the checkbox with correct label', () => {
      expect(findFormCheckbox().exists()).toBe(true);
      expect(findFormCheckbox().text()).toContain('Allow external MCP tools');
    });

    it('renders the help text correctly', () => {
      expect(findFormCheckbox().text()).toContain('Allow the IDE to access external MCP tools.');
    });

    it.each([[false], [true]])(
      'sets checkbox with the isMcpEnabled prop %p',
      async (isMcpEnabled) => {
        wrapper = createComponent({ isMcpEnabled });

        await nextTick();

        expect(findFormCheckbox().props('checked')).toBe(isMcpEnabled);
      },
    );

    describe('when checkbox is clicked', () => {
      beforeEach(async () => {
        findFormCheckbox().vm.$emit('change', true);
        await nextTick();
      });

      it('emits the `mcp-change` event with the correct payload', () => {
        expect(wrapper.emitted('mcp-change')[0]).toEqual([true]);
      });
    });

    it('renders checkbox with correct data-testid attribute', () => {
      expect(findFormCheckbox().find('input').attributes('data-testid')).toBe(
        'enable-duo-workflow-mcp-enabled-checkbox',
      );
    });

    it('renders checkbox with correct name attribute', () => {
      expect(findFormCheckbox().props('name')).toBe(
        'namespace[ai_settings_attributes][duo_workflow_mcp_enabled]',
      );
    });
  });

  describe('Prompt Injection Protection Section', () => {
    it('renders the protection section with correct label', () => {
      const formGroup = wrapper.findComponent(GlFormGroup);
      expect(formGroup.exists()).toBe(true);
      expect(wrapper.text()).toContain('Prompt injection protection');
    });

    it('renders the protection description as label-description', () => {
      expect(wrapper.text()).toContain(
        'Control how GitLab Duo handles potential prompt injection attempts',
      );
    });

    it('renders radio group with correct attributes', () => {
      expect(findRadioGroup().attributes('data-testid')).toBe(
        'prompt-injection-protection-level-radio-group',
      );
      expect(findRadioGroup().attributes('name')).toBe(
        'namespace[ai_settings_attributes][prompt_injection_protection_level]',
      );
    });

    it('renders all three protection level options', () => {
      expect(findRadios()).toHaveLength(3);
    });

    it.each(PROTECTION_LEVEL_OPTIONS)(
      'renders $value option with correct text and description',
      (option) => {
        const radioIndex = PROTECTION_LEVEL_OPTIONS.findIndex((opt) => opt.value === option.value);
        const radio = findRadios().at(radioIndex);

        expect(radio.text()).toContain(option.text);
        expect(radio.text()).toContain(option.description);
        expect(radio.attributes('data-testid')).toBe(
          `prompt-injection-protection-${option.value}-radio`,
        );
      },
    );

    describe('when radio selection changes', () => {
      beforeEach(async () => {
        findRadioGroup().vm.$emit('change', 'log_only');
        await nextTick();
      });

      it('emits protection-level-change event with correct value', () => {
        expect(wrapper.emitted('protection-level-change')[0]).toEqual(['log_only']);
      });
    });
  });

  describe('Component Structure', () => {
    it('renders both sections in correct order', () => {
      const headings = wrapper.findAll('h5');
      expect(headings).toHaveLength(1);
      expect(headings.at(0).text()).toContain('External MCP tools');
    });

    it('renders form group for protection settings', () => {
      const formGroups = wrapper.findAllComponents(GlFormGroup);
      expect(formGroups.length).toBeGreaterThan(0);
    });

    it('hides MCP section when showMcp is false', () => {
      wrapper = createComponent({ showMcp: false });
      expect(wrapper.findAll('h5')).toHaveLength(0);
      expect(findFormCheckbox().exists()).toBe(false);
    });

    it('hides protection section when showProtection is false', () => {
      wrapper = createComponent({ showProtection: false });
      expect(wrapper.findComponent(GlFormGroup).exists()).toBe(false);
    });

    it('shows only MCP section when protection is hidden', () => {
      wrapper = createComponent({ showProtection: false });
      expect(wrapper.findAll('h5')).toHaveLength(1);
      expect(findFormCheckbox().exists()).toBe(true);
    });

    it('shows only protection section when MCP is hidden', () => {
      wrapper = createComponent({ showMcp: false });
      expect(wrapper.findAll('h5')).toHaveLength(0);
      expect(wrapper.findComponent(GlFormGroup).exists()).toBe(true);
    });
  });

  describe('Form Attributes', () => {
    it('renders radio options with proper styling', () => {
      const radios = findRadios();
      radios.wrappers.forEach((radio) => {
        const div = radio.find('div');
        expect(div.exists()).toBe(true);
        const description = div.find('.gl-text-subtle');
        expect(description.exists()).toBe(true);
      });
    });
  });
});
