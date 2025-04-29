import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubgroupsQuery from 'ee/security_inventory/graphql/subgroups.query.graphql';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import ExpandableGroup from 'ee/security_inventory/components/sidebar/expandable_group.vue';
import { groupWithSubgroups } from '../../mock_data';

Vue.use(VueApollo);

describe('GroupList', () => {
  let wrapper;

  const findSubgroupAt = (i) => wrapper.findAllComponents(ExpandableGroup).at(i);

  const createComponent = async ({
    resolvedValue = groupWithSubgroups,
    groupFullPath = 'a-group',
    activeFullPath = 'a_group',
    indentation = 0,
  } = {}) => {
    wrapper = shallowMountExtended(GroupList, {
      apolloProvider: createMockApollo([
        [SubgroupsQuery, jest.fn().mockResolvedValue(resolvedValue)],
      ]),
      propsData: {
        groupFullPath,
        activeFullPath,
        indentation,
      },
    });
    await waitForPromises();
  };

  it('shows an expandable group for each subgroup of the main group', async () => {
    await createComponent();

    expect(findSubgroupAt(0).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-projects-and-subgroups',
      },
    });
    expect(findSubgroupAt(1).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-projects',
      },
    });
    expect(findSubgroupAt(2).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-subgroups',
      },
    });
    expect(findSubgroupAt(3).props()).toMatchObject({
      group: {
        fullPath: 'a-group/empty-subgroup',
      },
    });
  });
});
