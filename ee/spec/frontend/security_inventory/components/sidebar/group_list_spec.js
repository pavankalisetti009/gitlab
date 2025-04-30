import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlIntersectionObserver } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockClient } from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubgroupsQuery from 'ee/security_inventory/graphql/subgroups.query.graphql';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import ExpandableGroup from 'ee/security_inventory/components/sidebar/expandable_group.vue';
import { groupWithSubgroups } from '../../mock_data';

Vue.use(VueApollo);

describe('GroupList', () => {
  let wrapper;
  let mockApollo;

  const findSubgroupAt = (i) => wrapper.findAllComponents(ExpandableGroup).at(i);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const createComponent = async ({
    resolvedValue = groupWithSubgroups,
    groupFullPath = 'a-group',
    activeFullPath = 'a-group',
    indentation = 0,
    queryHandler = jest.fn().mockResolvedValue(resolvedValue),
  } = {}) => {
    const mockDefaultClient = createMockClient();
    const mockAppendGroupsClient = createMockClient([[SubgroupsQuery, queryHandler]]);

    mockApollo = new VueApollo({
      clients: {
        defaultClient: mockDefaultClient,
        appendGroupsClient: mockAppendGroupsClient,
      },
      defaultClient: mockDefaultClient,
    });

    wrapper = shallowMountExtended(GroupList, {
      apolloProvider: mockApollo,
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

  it('loads more subgroups when scrolling down', async () => {
    const queryHandler = jest
      .fn()
      .mockResolvedValueOnce(groupWithSubgroups)
      .mockResolvedValueOnce(groupWithSubgroups);

    await createComponent({ queryHandler });

    expect(queryHandler).toHaveBeenNthCalledWith(1, { fullPath: 'a-group' });

    findIntersectionObserver().vm.$emit('appear');
    await nextTick();

    expect(queryHandler).toHaveBeenNthCalledWith(2, { after: 'END_CURSOR' });
  });
});
