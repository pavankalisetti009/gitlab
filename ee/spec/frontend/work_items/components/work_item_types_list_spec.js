import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlButton,
  GlDisclosureDropdown,
  GlLoadingIcon,
  GlDisclosureDropdownItem,
  GlButtonGroup,
} from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemTypesList from 'ee/work_items/components/work_item_types_list.vue';
import CreateEditWorkItemTypeForm from '~/work_items/components/create_edit_work_item_type_form.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import organisationWorkItemTypesQuery from '~/work_items/graphql/organisation_work_item_types.query.graphql';
import {
  namespaceWorkItemTypesQueryResponse,
  organisationWorkItemTypesQueryResponse,
  mockWorkItemTypesConfigurationResponse,
} from 'ee_else_ce_jest/work_items/mock_data';
import { DEFAULT_SETTINGS_CONFIG } from 'ee/work_items/constants';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';

Vue.use(VueApollo);

describe('WorkItemTypesList', () => {
  let wrapper;
  let mockApollo;

  const buildNamespaceResponse = (nodes) => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        workItemTypes: {
          nodes,
          __typename: 'WorkItemTypeConnection',
        },
        __typename: 'Namespace',
      },
    },
  });

  const mockEmptyResponse = buildNamespaceResponse([]);

  const getMockWorkItemTypes = () =>
    mockWorkItemTypesConfigurationResponse.data.namespace.workItemTypes.nodes;
  const getMockOrganisationWorkItemTypes = () =>
    organisationWorkItemTypesQueryResponse.data.organisation.workItemTypes.nodes;
  const mockOrganisationWorkItemTypes = getMockOrganisationWorkItemTypes();
  const mockWorkItemTypes = getMockWorkItemTypes();
  const namespaceQueryHandler = jest.fn().mockResolvedValue(mockWorkItemTypesConfigurationResponse);
  const mockEmptyResponseHandler = jest.fn().mockResolvedValue(mockEmptyResponse);

  const createWrapper = ({
    queryHandler = namespaceQueryHandler,
    props = {},
    mountFn = mountExtended,
  } = {}) => {
    const defaultProps = {
      config: {
        ...DEFAULT_SETTINGS_CONFIG,
      },
    };

    mockApollo = createMockApollo([[workItemTypesConfigurationQuery, queryHandler]]);

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: organisationWorkItemTypesQuery,
      data: {
        organisation: {
          id: 'gid://gitlab/2',
          workItemTypes: {
            nodes: [...namespaceWorkItemTypesQueryResponse.data.namespace.workItemTypes.nodes],
          },
        },
      },
    });

    wrapper = mountFn(WorkItemTypesList, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath: 'test-group',
        ...defaultProps,
        ...props,
      },
      stubs: {
        CrudComponent,
        GlButton,
      },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findWorkItemTypesTable = () => wrapper.findByTestId('work-item-types-table');
  const findWorkItemTypeRows = () => wrapper.findAll('[data-testid^="work-item-type-row"]');
  const findWorkItemTypeRow = (id) => wrapper.findByTestId(`work-item-type-row-${id}`);
  const findLockedIconByRow = (id) => wrapper.findByTestId(`locked-icon-${id}`);
  const findNewTypeButton = () => wrapper.findByTestId('new-type-button');
  const findDropdownForType = (id) => findWorkItemTypeRow(id).findComponent(GlDisclosureDropdown);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findCreateEditForm = () => wrapper.findComponent(CreateEditWorkItemTypeForm);
  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findArchiveButtons = () => findButtonGroup().findAllComponents(GlButton);
  const findActiveButton = () => findArchiveButtons().at(0);
  const findArchivedButton = () => findArchiveButtons().at(1);

  const findLockIconTooltip = (typeId) => {
    const icon = findLockedIconByRow(typeId);
    return icon.attributes('title');
  };

  describe('default rendering', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the component with CrudComponent', () => {
      expect(findCrudComponent().exists()).toBe(true);
    });

    it('renders with correct title and count', () => {
      expect(findCrudComponent().props('title')).toBe('Types');
      expect(findCrudComponent().props('count')).toBe(mockWorkItemTypes.length);
    });

    it('renders the work item types table', () => {
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });

    it('renders WorkItemTypeIcon for each type', () => {
      const icons = wrapper.findAllComponents(WorkItemTypeIcon);

      expect(icons).toHaveLength(mockWorkItemTypes.length);
      icons.wrappers.forEach((icon, index) => {
        expect(icon.props()).toMatchObject({
          workItemType: mockWorkItemTypes[index].name,
        });
      });
    });

    it('renders New type button', () => {
      expect(findNewTypeButton().exists()).toBe(true);
      expect(findNewTypeButton().text()).toContain('New type');
    });

    it('renders dropdown for each work item type', () => {
      const dropdowns = wrapper.findAllComponents(GlDisclosureDropdown);

      expect(dropdowns).toHaveLength(mockWorkItemTypes.length);
    });

    it('renders dropdowns with correct items', () => {
      mockWorkItemTypes.forEach((mockWorkItemType) => {
        const dropdown = findDropdownForType(mockWorkItemType.id);
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem)).toHaveLength(2);
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(0).text()).toContain(
          'Edit name and icon',
        );
        expect(dropdown.findAllComponents(GlDisclosureDropdownItem).at(1).text()).toContain(
          'Delete',
        );
      });
    });

    it('renders dropdown with correct toggle attributes', () => {
      const dropdown = findDropdownForType(mockWorkItemTypes[0].id);

      expect(dropdown.props('toggleId')).toBe(`work-item-type-actions-${mockWorkItemTypes[0].id}`);
      expect(dropdown.props('icon')).toBe('ellipsis_v');
      expect(dropdown.props('noCaret')).toBe(true);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows loading state when query is loading', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findWorkItemTypesTable().exists()).toBe(false);
    });

    it('hides loading state after query resolves', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      createWrapper({ queryHandler: mockEmptyResponseHandler });
      await waitForPromises();
    });

    it('renders table even when no work item types exist', () => {
      expect(findWorkItemTypesTable().exists()).toBe(true);
    });

    it('displays zero count', () => {
      expect(findCrudComponent().props('count')).toBe(0);
    });

    it('does not render any work item type rows', () => {
      expect(findWorkItemTypeRows()).toHaveLength(0);
    });

    it('still renders New type button', () => {
      expect(findNewTypeButton().exists()).toBe(true);
    });
  });

  describe('namespace work item types query', () => {
    it('passes correct fullPath to query', async () => {
      createWrapper({ props: { fullPath: 'my-group/sub-group' } });

      await waitForPromises();

      expect(namespaceQueryHandler).toHaveBeenCalledWith({
        fullPath: 'my-group/sub-group',
      });
    });

    it('error handling', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item types');
    });
  });

  describe('CreateEditWorkItemTypeForm integration', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: shallowMountExtended });
      await waitForPromises();
    });

    it('form is hidden by default', () => {
      expect(findCreateEditForm().props('isVisible')).toBe(false);
    });

    it('opens form when New type button is clicked', async () => {
      await findNewTypeButton().vm.$emit('click');

      expect(findCreateEditForm().props('isVisible')).toBe(true);
      expect(findCreateEditForm().props('isEditMode')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it('opens form in edit mode when Edit action is clicked', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await editItem.vm.$emit('action');

      expect(findCreateEditForm().props('isVisible')).toBe(true);
      expect(findCreateEditForm().props('isEditMode')).toBe(true);
      expect(findCreateEditForm().props('workItemType')).toEqual(
        expect.objectContaining({ id: firstType.id }),
      );
    });

    it('closes form when close event is emitted', async () => {
      await findNewTypeButton().vm.$emit('click');
      expect(findCreateEditForm().props('isVisible')).toBe(true);

      await findCreateEditForm().vm.$emit('close');

      expect(findCreateEditForm().props('isVisible')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it('clears selected work item type when form closes', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      await editItem.vm.$emit('action');
      expect(findCreateEditForm().props('workItemType')).toEqual(
        expect.objectContaining({ id: firstType.id }),
      );

      await findCreateEditForm().vm.$emit('close');

      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });

    it('opens form in create mode after closing edit mode', async () => {
      const firstType = mockWorkItemTypes[0];
      const dropdown = findDropdownForType(firstType.id);
      const editItem = dropdown.findAllComponents(GlDisclosureDropdownItem).at(0);

      // Open in edit mode
      await editItem.vm.$emit('action');
      expect(findCreateEditForm().props('isEditMode')).toBe(true);

      // Close form
      await findCreateEditForm().vm.$emit('close');

      // Open in create mode
      await findNewTypeButton().vm.$emit('click');
      expect(findCreateEditForm().props('isEditMode')).toBe(false);
      expect(findCreateEditForm().props('workItemType')).toBe(null);
    });
  });

  describe('organisation query', () => {
    beforeEach(async () => {
      createWrapper({ props: { fullPath: '' } });
      await waitForPromises();
    });

    it('renders work item types from organisation query', () => {
      expect(findWorkItemTypeRows()).toHaveLength(mockOrganisationWorkItemTypes.length);

      mockOrganisationWorkItemTypes.forEach((type) => {
        expect(findWorkItemTypeRow(type.id).exists()).toBe(true);
      });
    });

    it('displays correct count from organisation data', () => {
      expect(findCrudComponent().props('count')).toBe(mockOrganisationWorkItemTypes.length);
    });

    it('renders WorkItemTypeIcon for each organisation work item type', () => {
      const icons = wrapper.findAllComponents(WorkItemTypeIcon);

      expect(icons).toHaveLength(mockOrganisationWorkItemTypes.length);
      icons.wrappers.forEach((icon, index) => {
        expect(icon.props()).toMatchObject({
          workItemType: mockOrganisationWorkItemTypes[index].name,
        });
      });
    });

    it('renders dropdowns for organisation work item types', () => {
      const dropdowns = wrapper.findAllComponents(GlDisclosureDropdown);

      expect(dropdowns).toHaveLength(mockOrganisationWorkItemTypes.length);
    });

    it('renders dropdowns with correct items for organisation types', () => {
      mockOrganisationWorkItemTypes.forEach((mockWorkItemType) => {
        const dropdown = findDropdownForType(mockWorkItemType.id);
        const dropdownItems = dropdown.findAllComponents(GlDisclosureDropdownItem);
        expect(dropdownItems).toHaveLength(2);
        expect(dropdownItems.at(0).text()).toContain('Edit name and icon');
        expect(dropdownItems.at(1).text()).toContain('Delete');
      });
    });
  });

  describe('error handling', () => {
    it('handles namespace query error', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).toContain('Failed to fetch work item types');
    });

    it('allows dismissing error alert', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue('Network error');
      createWrapper({ queryHandler: errorQueryHandler });

      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);

      await findErrorAlert().vm.$emit('dismiss');

      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('query selection based on fullPath', () => {
    it('does not call namespace query when fullPath is empty', async () => {
      createWrapper({ props: { fullPath: '' } });
      await waitForPromises();

      expect(namespaceQueryHandler).not.toHaveBeenCalled();
    });

    it('calls namespace query when fullPath is provided', async () => {
      createWrapper({ props: { fullPath: 'test-group' } });
      await waitForPromises();

      expect(namespaceQueryHandler).toHaveBeenCalled();
    });
  });

  describe('locked configuration tooltip', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('does not render locked icons configurable work item types', () => {
      const firstType = mockWorkItemTypes[0];
      const lockIcon = findLockedIconByRow(firstType.id);

      expect(lockIcon.exists()).toBe(false);
    });

    it('includes service desk message when isServiceDesk is true', async () => {
      const serviceDeskType = {
        ...mockWorkItemTypes[0],
        isServiceDesk: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([serviceDeskType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(serviceDeskType.id);
      expect(tooltipText).toContain('Usage is controlled by the Service Desk feature.');
    });

    it('includes group limitation message when isGroupWorkItemType is true', async () => {
      const groupType = {
        ...mockWorkItemTypes[0],
        isGroupWorkItemType: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([groupType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(groupType.id);
      expect(tooltipText).toContain('Usage is limited to groups.');
    });

    it('includes incident message when isIncidentManagement is true', async () => {
      const incidentType = {
        ...mockWorkItemTypes[0],
        isIncidentManagement: true,
        isConfigurable: false,
      };

      const queryHandler = jest.fn().mockResolvedValue(buildNamespaceResponse([incidentType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const tooltipText = findLockIconTooltip(incidentType.id);
      expect(tooltipText).toContain('Usage is controlled by the Monitor feature.');
    });

    it('does not render lock icon for configurable types', async () => {
      const nonConfigurableType = {
        ...mockWorkItemTypes[0],
        isConfigurable: true,
      };

      const queryHandler = jest
        .fn()
        .mockResolvedValue(buildNamespaceResponse([nonConfigurableType]));

      createWrapper({ queryHandler });
      await waitForPromises();

      const lockIcon = findLockedIconByRow(nonConfigurableType.id);
      expect(lockIcon.exists()).toBe(false);
    });
  });

  describe('archive/unarchive button group', () => {
    describe('visibility', () => {
      it('does not render button group when no archived types exist', async () => {
        createWrapper();
        await waitForPromises();

        expect(findButtonGroup().exists()).toBe(false);
      });

      it('renders button group when archived types exist', async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();

        expect(findButtonGroup().exists()).toBe(true);
      });
    });

    describe('button labels and state', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('renders Active and Archived buttons and Active button is selected by default', () => {
        expect(findActiveButton().text()).toContain('Active');
        expect(findArchivedButton().text()).toContain('Archived');

        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);
      });
    });

    describe('filtering functionality', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          id: 'gid://gitlab/WorkItemType/1',
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          id: 'gid://gitlab/WorkItemType/2',
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('displays only active types when Active button is selected', () => {
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);
      });

      it('displays only archived types when Archived button is clicked', async () => {
        await findArchivedButton().vm.$emit('click');

        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/1').exists()).toBe(true);
      });

      it('toggles between active and archived types', async () => {
        // Initially showing active types
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);

        // Click Archived button
        await findArchivedButton().vm.$emit('click');
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/1').exists()).toBe(true);

        // Click Active button again
        await findActiveButton().vm.$emit('click');
        expect(findWorkItemTypeRows()).toHaveLength(1);
        expect(findWorkItemTypeRow('gid://gitlab/WorkItemType/2').exists()).toBe(true);
      });
    });

    describe('title and description changes', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('displays "Types" title when showing active types', () => {
        expect(findCrudComponent().props('title')).toBe('Types');
      });

      it('displays "Archived types" title when showing archived types', async () => {
        await findArchivedButton().vm.$emit('click');

        expect(findCrudComponent().props('title')).toBe('Archived types');
      });

      it('displays description only when showing archived types', async () => {
        expect(findCrudComponent().props('description')).toBe('');

        await findArchivedButton().vm.$emit('click');

        expect(findCrudComponent().props('description')).toContain(
          'Disabled in all groups and projects',
        );
      });

      it('clears description when switching back to active types', async () => {
        await findArchivedButton().vm.$emit('click');
        expect(findCrudComponent().props('description')).not.toBe('');

        await findActiveButton().vm.$emit('click');
        expect(findCrudComponent().props('description')).toBe('');
      });
    });

    describe('button selection state', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('updates selected state when Active button is clicked', async () => {
        await findArchivedButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(false);
        expect(findArchivedButton().props('selected')).toBe(true);

        await findActiveButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);
      });

      it('updates selected state when Archived button is clicked', async () => {
        expect(findActiveButton().props('selected')).toBe(true);
        expect(findArchivedButton().props('selected')).toBe(false);

        await findArchivedButton().vm.$emit('click');
        expect(findActiveButton().props('selected')).toBe(false);
        expect(findArchivedButton().props('selected')).toBe(true);
      });
    });

    describe('New type button visibility', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType = {
          ...mockWorkItemTypes[1],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('shows New type button when viewing active types', () => {
        expect(findNewTypeButton().exists()).toBe(true);
      });

      it('hides New type button when viewing archived types', async () => {
        await findArchivedButton().trigger('click');

        expect(findNewTypeButton().exists()).toBe(false);
      });

      it('shows New type button again when switching back to active types', async () => {
        await findArchivedButton().trigger('click');
        expect(findNewTypeButton().exists()).toBe(false);

        await findActiveButton().vm.$emit('click');
        expect(findNewTypeButton().exists()).toBe(true);
      });
    });

    describe('count updates', () => {
      beforeEach(async () => {
        const archivedType = {
          ...mockWorkItemTypes[0],
          archived: true,
        };
        const activeType1 = {
          ...mockWorkItemTypes[1],
          archived: false,
        };
        const activeType2 = {
          ...mockWorkItemTypes[2],
          archived: false,
        };

        const queryHandler = jest
          .fn()
          .mockResolvedValue(buildNamespaceResponse([archivedType, activeType1, activeType2]));

        createWrapper({ queryHandler });
        await waitForPromises();
      });

      it('displays correct count for active types', () => {
        expect(findCrudComponent().props('count')).toBe(2);
      });

      it('displays correct count for archived types', async () => {
        await findArchivedButton().vm.$emit('click');

        expect(findCrudComponent().props('count')).toBe(1);
      });

      it('updates count when switching between tabs', async () => {
        expect(findCrudComponent().props('count')).toBe(2);

        await findArchivedButton().vm.$emit('click');
        expect(findCrudComponent().props('count')).toBe(1);

        await findActiveButton().vm.$emit('click');
        expect(findCrudComponent().props('count')).toBe(2);
      });
    });
  });
});
