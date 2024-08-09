import { nextTick } from 'vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(StatusChecks);
  });

  const findStatusChecksTable = () => wrapper.findByTestId('status-checks-table');
  const findStatusChecksDrawer = () => wrapper.findByTestId('status-checks-drawer');

  it('should open the drawer when add event is emitted', async () => {
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('add');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(true);
  });

  it('should close the drawer when close event is emitted', async () => {
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('edit');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(true);

    findStatusChecksDrawer().vm.$emit('close');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });
});
