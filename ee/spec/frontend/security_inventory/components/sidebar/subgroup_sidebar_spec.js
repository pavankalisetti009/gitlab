import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PanelResizer from '~/vue_shared/components/panel_resizer.vue';
import SubgroupsQuery from 'ee/security_inventory/graphql/subgroups.query.graphql';
import SubgroupSidebar from 'ee/security_inventory/components/sidebar/subgroup_sidebar.vue';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { groupWithSubgroups } from '../../mock_data';

Vue.use(VueApollo);

describe('SubgroupSidebar', () => {
  useLocalStorageSpy();

  let wrapper;

  const findPanelWidth = () => wrapper.findByTestId('panel').element.style.width;
  const resizePanel = (size) => wrapper.findComponent(PanelResizer).vm.$emit('update:size', size);

  const createComponent = async ({
    groupFullPath = 'a-group',
    activeFullPath = 'a-group',
    mountFn = shallowMountExtended,
    queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups),
  } = {}) => {
    wrapper = mountFn(SubgroupSidebar, {
      apolloProvider: createMockApollo([[SubgroupsQuery, queryHandler]]),
      provide: {
        groupFullPath,
      },
      propsData: {
        activeFullPath,
      },
    });
    await waitForPromises();
  };

  describe('group details and navigation', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('shows the avatar and name of the main group', () => {
      expect(wrapper.findComponent(ProjectAvatar).props()).toMatchObject({
        projectName: 'A group',
        projectAvatarUrl: 'a_group_avatar.png',
      });
      expect(wrapper.text()).toBe('A group');
    });

    it('shows a list of subgroups of the main group', () => {
      expect(wrapper.findComponent(GroupList).props()).toStrictEqual({
        groupFullPath: 'a-group',
        activeFullPath: 'a-group',
        indentation: 0,
      });
    });

    it('when selectSubgroup is emitted, navigates to the selected subgroup', () => {
      const subgroup = { fullPath: 'a-group/one-subgroup' };

      expect(window.location.hash).toBe('');

      wrapper.findComponent(GroupList).vm.$emit('selectSubgroup', subgroup.fullPath);

      expect(window.location.hash).toBe(`#${subgroup.fullPath}`);
    });
  });

  describe('resizable width', () => {
    it('passes correct props to PanelResizer', () => {
      createComponent();

      expect(wrapper.findComponent(PanelResizer).props()).toMatchObject({
        startSize: 300,
        side: 'right',
        minSize: 200,
        enabled: true,
      });
    });

    it('updates width when PanelResizer emits update:size', async () => {
      createComponent();

      await resizePanel(350);

      expect(findPanelWidth()).toBe('350px');
    });

    it('persists through page reloads', async () => {
      createComponent({ mountFn: mountExtended });

      await resizePanel(400);
      await waitForPromises();

      expect(findPanelWidth()).toBe('400px');

      wrapper.destroy();
      createComponent({ mountFn: mountExtended });
      await waitForPromises();

      expect(findPanelWidth()).toBe('400px');
    });
  });
});
