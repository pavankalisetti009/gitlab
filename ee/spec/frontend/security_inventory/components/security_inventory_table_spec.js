import { nextTick } from 'vue';
import { shallowMount, mount } from '@vue/test-utils';
import { GlTableLite, GlSkeletonLoader, GlFormCheckbox } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import SecurityInventoryTable from 'ee/security_inventory/components/security_inventory_table.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import VulnerabilityCell from 'ee/security_inventory/components/vulnerability_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import AttributesCell from 'ee/security_inventory/components/attributes_cell.vue';
import CheckboxCell from 'ee/security_inventory/components/checkbox_cell.vue';
import {
  ACTION_TYPE_BULK_EDIT_SCANNERS,
  ACTION_TYPE_BULK_EDIT_ATTRIBUTES,
} from 'ee/security_inventory/constants';
import { subgroupsAndProjects } from '../mock_data';

const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
const anotherProject = subgroupsAndProjects.data.group.projects.nodes[1];
const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];
const items = [mockGroup, mockProject];

describe('SecurityInventoryTable', () => {
  let wrapper;
  let openDrawerSpy;

  const createComponentFactory = ({ mountFn = shallowMount } = {}) => {
    return ({
      props = {},
      stubs = {},
      provide = {
        groupFullPath: 'path/to/group',
        canManageAttributes: false,
        canReadAttributes: true,
        canApplyProfiles: false,
      },
    } = {}) => {
      wrapper = mountFn(SecurityInventoryTable, {
        propsData: {
          items,
          ...props,
        },
        stubs: {
          GlTableLite: { ...stubComponent(GlTableLite), props: ['items', 'fields'] },
          ...stubs,
        },
        provide: {
          glFeatures: { securityScanProfilesFeature: false },
          ...provide,
        },
      });

      return wrapper;
    };
  };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory({ mountFn: mount });

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findSelectAllCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findItemCheckbox = () => wrapper.findComponent(CheckboxCell);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the table component', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('passes fields to GlTableLite component', () => {
      expect(findTable().props('fields')).toEqual([
        { key: 'name', label: 'Name', thClass: 'gl-w-1/4' },
        { key: 'vulnerabilities', label: 'Vulnerabilities', thClass: 'gl-w-1/5' },
        { key: 'toolCoverage', label: 'Tool Coverage', thClass: 'gl-w-1/3' },
        { key: 'securityAttributes', label: 'Security attributes', thClass: 'gl-w-1/6' },
        { key: 'actions', label: '', thClass: 'gl-w-2/20' },
      ]);
    });

    it('passes items to GlTableLite component', () => {
      expect(findTable().props('items')).toEqual(items);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createFullComponent({ props: { items: [], isLoading: true }, stubs: { GlTableLite: false } });
    });

    it('shows the correct number of skeleton rows when loading', () => {
      expect(findTableRows()).toHaveLength(3);
    });

    it('shows skeleton loaders for each column in a row', () => {
      const firstRow = findNthTableRow(0);
      const firstRowLoaders = firstRow.findAllComponents(GlSkeletonLoader);
      expect(firstRowLoaders).toHaveLength(5);
    });
  });

  describe('cell rendering', () => {
    beforeEach(() => {
      createFullComponent({ stubs: { GlTableLite: false } });
    });

    it('renders all required cell components', () => {
      expect(findTableRows()).toHaveLength(items.length);

      const firstRow = findNthTableRow(0);
      expect(firstRow.findComponent(NameCell).exists()).toBe(true);
      expect(firstRow.findComponent(VulnerabilityCell).exists()).toBe(true);
      expect(firstRow.findComponent(ToolCoverageCell).exists()).toBe(true);
      expect(firstRow.findComponent(AttributesCell).exists()).toBe(true);
      expect(firstRow.findComponent(ActionCell).exists()).toBe(true);
      expect(firstRow.findComponent(CheckboxCell).exists()).toBe(false);
    });
  });

  describe('bulk selection', () => {
    describe('with permission', () => {
      beforeEach(() => {
        createFullComponent({
          props: { items },
          stubs: { GlTableLite: false },
          provide: {
            canReadAttributes: true,
            canManageAttributes: true,
            canApplyProfiles: false,
            groupFullPath: 'path/to/group',
          },
        });
      });

      it('select all checkbox selects and deselects all visible items', () => {
        findSelectAllCheckbox().vm.$emit('change', true);

        expect(wrapper.emitted('selectedCount')[0]).toStrictEqual([2]);

        findSelectAllCheckbox().vm.$emit('change', false);

        expect(wrapper.emitted('selectedCount')[1]).toStrictEqual([0]);
      });

      it('checkbox cell selects and deselects a single item', () => {
        findItemCheckbox().vm.$emit('selectItem', items[0], true);

        expect(wrapper.emitted('selectedCount')[0]).toStrictEqual([1]);

        findItemCheckbox().vm.$emit('selectItem', items[0], false);

        expect(wrapper.emitted('selectedCount')[1]).toStrictEqual([0]);
      });
    });
  });

  describe('when user does not have permission', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          canManageAttributes: false,
          canReadAttributes: false,
          canApplyProfiles: false,
        },
      });
    });

    it('does not show the security attributes column', () => {
      expect(findTable().props('fields')).not.toContain(
        expect.objectContaining({ key: 'securityAttributes' }),
      );
    });
  });

  describe('bulkEdit method with action types', () => {
    beforeEach(() => {
      createFullComponent({
        stubs: {
          GlTableLite: false,
          BulkAttributesUpdateDrawer: stubComponent({
            methods: { openDrawer: jest.fn() },
          }),
          BulkScannersUpdateDrawer: stubComponent({
            methods: { openDrawer: jest.fn() },
          }),
        },
        provide: {
          glFeatures: { securityScanProfilesFeature: true },
          canApplyProfiles: true,
          canManageAttributes: true,
          canReadAttributes: true,
          groupFullPath: 'path/to/group',
        },
      });

      findSelectAllCheckbox().vm.$emit('change', true);
    });

    it('opens attributes drawer when called with attributes action type', async () => {
      await nextTick(); // Wait for drawer to be rendered after selection

      openDrawerSpy = jest.spyOn(wrapper.vm.$refs.bulkAttributesDrawer, 'openDrawer');

      wrapper.vm.bulkEdit(ACTION_TYPE_BULK_EDIT_ATTRIBUTES);
      await nextTick();

      expect(openDrawerSpy).toHaveBeenCalled();
    });

    it('opens scanners drawer when called with scanners action type', async () => {
      openDrawerSpy = jest.spyOn(wrapper.vm.$refs.bulkScannersDrawer, 'openDrawer');

      wrapper.vm.bulkEdit(ACTION_TYPE_BULK_EDIT_SCANNERS);
      await nextTick();

      expect(openDrawerSpy).toHaveBeenCalled();
    });
  });

  describe('openAttributesDrawer method', () => {
    beforeEach(() => {
      createFullComponent({
        stubs: {
          GlTableLite: false,
          ProjectAttributesUpdateDrawer: stubComponent({
            methods: { openDrawer: jest.fn() },
          }),
        },
      });
    });

    it('recreates drawer component when switching between different projects', async () => {
      wrapper.vm.openAttributesDrawer(mockProject);
      await nextTick();

      const firstDrawerInstance = wrapper.vm.$refs.attributesDrawer;

      wrapper.vm.openAttributesDrawer(anotherProject);
      await nextTick();

      const secondDrawerInstance = wrapper.vm.$refs.attributesDrawer;

      expect(firstDrawerInstance).not.toBe(secondDrawerInstance);
    });
  });

  describe('openSecurityConfigurationDrawer method', () => {
    let configDrawerSpy;

    beforeEach(() => {
      createFullComponent({
        stubs: {
          GlTableLite: false,
          ProjectSecurityConfigurationDrawer: stubComponent({
            methods: { openDrawer: jest.fn() },
          }),
        },
      });
    });

    it('opens security configuration drawer when called', async () => {
      wrapper.vm.openSecurityConfigurationDrawer(mockProject);
      await nextTick();

      configDrawerSpy = jest.spyOn(wrapper.vm.$refs.securityConfigurationDrawer, 'openDrawer');

      wrapper.vm.openSecurityConfigurationDrawer(mockProject);
      await nextTick();

      expect(wrapper.vm.selectedProjectForConfiguration).toStrictEqual(mockProject);
      expect(configDrawerSpy).toHaveBeenCalled();
    });

    it('recreates drawer component when switching between different projects', async () => {
      wrapper.vm.openSecurityConfigurationDrawer(mockProject);
      await nextTick();

      const firstDrawerInstance = wrapper.vm.$refs.securityConfigurationDrawer;

      wrapper.vm.openSecurityConfigurationDrawer(anotherProject);
      await nextTick();

      const secondDrawerInstance = wrapper.vm.$refs.securityConfigurationDrawer;

      expect(wrapper.vm.selectedProjectForConfiguration).toStrictEqual(anotherProject);
      expect(firstDrawerInstance).not.toBe(secondDrawerInstance);
    });
  });
});
