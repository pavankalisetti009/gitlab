import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIntersectionObserver } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubgroupsQuery from 'ee/security_inventory/graphql/subgroups.query.graphql';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import ExpandableGroup from 'ee/security_inventory/components/sidebar/expandable_group.vue';
import { groupWithSubgroups } from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('GroupList', () => {
  let wrapper;

  const findSubgroupAt = (i) => wrapper.findAllComponents(ExpandableGroup).at(i);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const createComponent = async ({
    groupFullPath = 'a-group',
    activeFullPath = 'a-group',
    indentation = 0,
    queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups),
  } = {}) => {
    wrapper = shallowMountExtended(GroupList, {
      apolloProvider: createMockApollo(
        [[SubgroupsQuery, queryHandler]],
        {},
        { typePolicies: { Query: { fields: { group: { merge: true } } } } },
      ),
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

  it('loads the next page of subgroups when scrolled to the bottom', async () => {
    const queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups);

    await createComponent({ queryHandler });

    expect(queryHandler).toHaveBeenNthCalledWith(1, { fullPath: 'a-group' });

    await findIntersectionObserver().vm.$emit('appear');

    expect(queryHandler).toHaveBeenNthCalledWith(2, { fullPath: 'a-group', after: 'END_CURSOR' });
  });

  it('shows an alert and reports to sentry on error', async () => {
    jest.spyOn(Sentry, 'captureException');
    const queryHandler = jest.fn().mockRejectedValue(new Error('Error'));

    await createComponent({ queryHandler });

    expect(createAlert).toHaveBeenCalledWith(
      expect.objectContaining({
        message: 'An error occurred while fetching subgroups. Please try again.',
      }),
    );
    expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Error'));
  });
});
