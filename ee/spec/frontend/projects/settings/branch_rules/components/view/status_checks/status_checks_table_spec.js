import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import StatusChecksTable from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks_table.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(StatusChecksTable, {
      propsData: {
        statusChecks: statusChecksRulesMock,
        ...propsData,
      },
      stubs: {
        CrudComponent,
        GlButton,
      },
    });
  };

  const findAddButton = () => wrapper.findByTestId('add-btn');
  const findEditButton = () => wrapper.findByTestId('edit-btn');
  const findCounterValue = () => wrapper.findByText(`${statusChecksRulesMock.length}`);
  const findStatusCheckEmptyState = () => wrapper.findByText('No status checks have been added.');

  beforeEach(() => createComponent());

  describe('renders correctly', () => {
    it('renders an empty state when there is no status checks', async () => {
      await createComponent({
        statusChecks: [],
      });
      expect(findStatusCheckEmptyState().exists()).toBe(true);
    });

    it('renders the correct status checks count', () => {
      expect(findCounterValue().exists()).toBe(true);
    });
  });

  describe('emits events to parent component', () => {
    it('emits add event when add button is clicked', async () => {
      findAddButton().vm.$emit('click');
      await nextTick();
      expect(wrapper.emitted('add')).toEqual([[]]);
    });
    it('emits edit event when edit button is clicked', async () => {
      findEditButton().vm.$emit('click');
      await nextTick();
      expect(wrapper.emitted('edit')).toEqual([[]]);
    });
  });
});
