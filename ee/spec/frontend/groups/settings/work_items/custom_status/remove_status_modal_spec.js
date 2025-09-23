import { GlModal, GlCollapsibleListbox, GlButton, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import RemoveStatusModal from 'ee/groups/settings/work_items/custom_status/remove_status_modal.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockLifecycles, statusCounts } from '../mock_data';

describe('RemoveStatusModal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);
  const findBodyText = () => wrapper.find('p');
  const findCurrentStatus = () => wrapper.findByTestId('current-status-value');
  const findNewStatusLabel = () => wrapper.find('label');
  const findNewStatusListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findNewStatusButton = () => findNewStatusListbox().findComponent(GlButton);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RemoveStatusModal, {
      propsData: {
        statusCounts,
        statusToRemove: mockLifecycles[0].statuses[0],
        statuses: mockLifecycles[0].statuses,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the modal with correct title', () => {
    expect(findModal().props('title')).toBe('Remove status');
  });

  it('emits hidden event when modal is hidden', () => {
    findModal().vm.$emit('hidden');

    expect(wrapper.emitted('hidden')).toEqual([[]]);
  });

  it('displays the correct body text', () => {
    expect(findBodyText().text()).toBe(
      `0 items currently use the status 'Karon Homenick'. Select a new status for these items.`,
    );
  });

  it('displays the current status details', () => {
    expect(findCurrentStatus().findComponent(GlIcon).props('name')).toBe('status-waiting');
    expect(findCurrentStatus().findComponent(GlIcon).attributes('style')).toBe(
      'color: rgb(115, 114, 120);',
    );
    expect(findCurrentStatus().text()).toBe('Karon Homenick');
  });

  it('displays the new status selection label', () => {
    expect(findNewStatusLabel().text()).toBe('New status');
  });

  it('filters out the status to remove from the listbox items', () => {
    const expected = [...mockLifecycles[0].statuses];
    expected.shift();

    expect(findNewStatusListbox().props('items')).toEqual(
      expected.map((status) => ({ ...status, text: status.name, value: status.id })),
    );
  });

  it('pre-selects the first available status in the listbox', () => {
    const expectedSelectedStatus = mockLifecycles[0].statuses.find(
      (status) => status.id !== mockLifecycles[0].statuses[0].id,
    );

    expect(findNewStatusListbox().props('selected')).toBe(expectedSelectedStatus.id);
    expect(findNewStatusButton().text()).toBe(expectedSelectedStatus.name);
    expect(findNewStatusButton().findComponent(GlIcon).props('name')).toBe(
      expectedSelectedStatus.iconName,
    );
    expect(findNewStatusButton().findComponent(GlIcon).attributes('style')).toBe(
      'color: rgb(16, 133, 72);',
    );
  });

  it('updates selectedNewStatusId when a new status is selected', async () => {
    const newSelection = mockLifecycles[0].statuses[2];

    findNewStatusListbox().vm.$emit('select', newSelection.id);
    await nextTick();

    expect(findNewStatusListbox().props('selected')).toBe(newSelection.id);
    expect(findNewStatusButton().text()).toBe(newSelection.name);
    expect(findNewStatusButton().findComponent(GlIcon).props('name')).toBe(newSelection.iconName);
    expect(findNewStatusButton().findComponent(GlIcon).attributes('style')).toBe(
      'color: rgb(221, 43, 14);',
    );
  });
});
