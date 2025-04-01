import { shallowMount } from '@vue/test-utils';
import GroupedTable from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_table.vue';
import TablePart from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/table_part.vue';

const fakeGroup = [
  {
    id: 1,
    status: 'failed',
    requirement: 'req1',
    framework: 'fw1',
    project: 'proj1',
    lastScanned: '2023-01-01',
  },
  {
    id: 2,
    status: 'passed',
    requirement: 'req2',
    framework: 'fw2',
    project: 'proj2',
    lastScanned: '2023-01-02',
  },
];

describe('GroupedTable', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(GroupedTable, {
      propsData: {
        items: [{ group: null, children: fakeGroup }],
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('when grouping is not present', () => {
    it('passes the correct props to TablePart', () => {
      const tablePart = wrapper.findComponent(TablePart);
      expect(tablePart.props('items')).toStrictEqual(fakeGroup);
    });
  });

  describe('event handling', () => {
    it('passes through row-selected event when TablePart emits it', () => {
      const rowData = { id: 1 };
      wrapper.findComponent(TablePart).vm.$emit('row-selected', rowData);
      expect(wrapper.emitted('row-selected')[0]).toEqual([rowData]);
    });
  });
});
