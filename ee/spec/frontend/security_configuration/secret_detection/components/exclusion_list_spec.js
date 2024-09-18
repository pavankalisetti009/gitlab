import { shallowMount } from '@vue/test-utils';
import { GlTable, GlIcon, GlButton, GlToggle } from '@gitlab/ui';
import ExclusionList from 'ee/security_configuration/secret_detection/components/exclusion_list.vue';

describe('ExclusionList', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ExclusionList, {
      propsData: {
        exclusions: [],
        ...props,
      },
      stubs: {
        GlTable,
        GlIcon,
        GlButton,
        GlToggle,
      },
    });
  };

  it('renders the component', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('displays the correct heading text', () => {
    createComponent();
    expect(wrapper.text()).toContain(
      'Specify file paths, raw values, and regex that should be excluded by secret detection in this project.',
    );
  });

  it('renders the "Add exclusion" button', () => {
    createComponent();
    const addButton = wrapper.findComponent(GlButton);
    expect(addButton.exists()).toBe(true);
    expect(addButton.text()).toBe('Add exclusion');
  });

  it('renders the GlTable component', () => {
    createComponent();
    expect(wrapper.findComponent(GlTable).exists()).toBe(true);
  });

  it('passes the correct fields to the GlTable', () => {
    createComponent();
    const table = wrapper.findComponent(GlTable);
    expect(table.props('fields')).toHaveLength(6);
    expect(table.props('fields').map((field) => field.key)).toEqual([
      'status',
      'type',
      'content',
      'enforcement',
      'modified',
      'actions',
    ]);
  });
});
