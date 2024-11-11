import { GlSprintf } from '@gitlab/ui';
import Api from '~/api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlockGroupBranchModificationSetting from 'ee/security_orchestration/components/policy_drawer/scan_result/block_group_branch_modification_setting.vue';
import { TOP_LEVEL_GROUPS } from 'ee_jest/security_orchestration/mocks/mock_data';

describe('BlockGroupBranchModificationSetting', () => {
  let wrapper;

  const createComponent = (exceptions = []) => {
    wrapper = shallowMountExtended(BlockGroupBranchModificationSetting, {
      propsData: { exceptions },
      stubs: { GlSprintf },
    });
  };

  const findExceptions = () => wrapper.findAll('li');

  beforeEach(() => {
    jest.spyOn(Api, 'group').mockResolvedValueOnce(TOP_LEVEL_GROUPS[0]).mockRejectedValueOnce();
  });

  it('renders exception list items', async () => {
    createComponent([{ id: 1 }, { id: 2 }]);
    await waitForPromises();
    const exceptions = findExceptions();
    expect(exceptions).toHaveLength(2);
    expect(exceptions.at(0).text()).toBe('Group-1');
    expect(exceptions.at(1).text()).toBe('Group ID: 2');
  });
});
