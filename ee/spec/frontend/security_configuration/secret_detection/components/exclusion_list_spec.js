import { mount, shallowMount } from '@vue/test-utils';
import { GlTable, GlButton, GlToggle } from '@gitlab/ui';
import { EXCLUSION_TYPE_MAP } from 'ee/security_configuration/secret_detection/constants';
import ExclusionList from 'ee/security_configuration/secret_detection/components/exclusion_list.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { projectSecurityExclusions } from '../mock_data';

describe('ExclusionList', () => {
  let wrapper;

  const createComponentFactory =
    (mountFn = shallowMount) =>
    ({ props = {} } = {}) => {
      wrapper = mountFn(ExclusionList, {
        propsData: {
          exclusions: projectSecurityExclusions,
          ...props,
        },
        provide: {
          projectFullPath: 'group/project',
        },
      });
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mount);

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRowCells = (idx) => findTable().find('tbody').findAll('tr').at(idx).findAll('td');

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

  it('emits corrects event when the "Add exclusion" button is clicked', async () => {
    createComponent();
    const addButton = wrapper.findComponent(GlButton);
    await addButton.vm.$emit('click');
    expect(wrapper.emitted('addExclusion')).toHaveLength(1);
  });

  describe('Table', () => {
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

    it('should render correct values', () => {
      createFullComponent();

      const rowCells = findTableRowCells(0);
      const [exclusion] = projectSecurityExclusions;

      expect(rowCells).toHaveLength(6);

      expect(rowCells.at(0).text()).toBe('Toggle exclusion');
      expect(rowCells.at(0).findComponent(GlToggle).props('value')).toBe(exclusion.active);
      expect(rowCells.at(1).text()).toBe(EXCLUSION_TYPE_MAP[exclusion.type].text);
      expect(rowCells.at(2).text()).toBe(exclusion.value);
      expect(rowCells.at(3).text()).toContain('Secret push protection');
      expect(rowCells.at(4).text()).toContain(getTimeago().format(exclusion.updatedAt));
    });
  });
});
