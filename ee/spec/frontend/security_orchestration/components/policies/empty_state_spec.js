import { GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import EmptyState from 'ee/security_orchestration/components/policies/empty_state.vue';

describe('EmptyState component', () => {
  let wrapper;

  const findEmptyFilterState = () => wrapper.findByTestId('empty-filter-state');
  const findEmptyListState = () => wrapper.findByTestId('empty-list-state');

  const factory = ({
    disableScanPolicyUpdate = false,
    hasExistingPolicies = false,
    hasPolicyProject = false,
    namespaceType = NAMESPACE_TYPES.PROJECT,
  } = {}) => {
    wrapper = shallowMountExtended(EmptyState, {
      propsData: {
        hasExistingPolicies,
        hasPolicyProject,
      },
      provide: {
        disableScanPolicyUpdate,
        emptyFilterSvgPath: 'path/to/filter/svg',
        emptyListSvgPath: 'path/to/list/svg',
        namespaceType,
        newPolicyPath: 'path/to/new/policy',
      },
      stubs: { GlSprintf },
    });
  };

  it.each`
    title                                        | findComponent           | state    | factoryFn
    ${'does not display the empty filter state'} | ${findEmptyFilterState} | ${false} | ${factory}
    ${'does display the empty list state'}       | ${findEmptyListState}   | ${true}  | ${factory}
    ${'does display the empty filter state'}     | ${findEmptyFilterState} | ${true}  | ${() => factory({ hasExistingPolicies: true })}
    ${'does not display the empty list state'}   | ${findEmptyListState}   | ${false} | ${() => factory({ hasExistingPolicies: true })}
  `('$title', async ({ factoryFn, findComponent, state }) => {
    factoryFn();
    await nextTick();
    expect(findComponent().exists()).toBe(state);
  });

  it('displays the correct empty list state when there is not a policy project', async () => {
    factory();
    await nextTick();
    expect(findEmptyListState().text()).toContain(
      'This project is not linked to a security policy project. Either link it to an existing project or create a new policy, which will create a new project that you can use as a security policy project. For help, see',
    );
  });

  it('displays the correct empty list state when there is a policy project', async () => {
    factory({ hasPolicyProject: true });
    await nextTick();
    expect(findEmptyListState().text()).toContain(
      'This project does not contain any security policies.',
    );
  });

  it.each`
    title                                                   | namespaceType
    ${'does display the correct description for a project'} | ${NAMESPACE_TYPES.PROJECT}
    ${'does display the correct description for a group'}   | ${NAMESPACE_TYPES.GROUP}
  `('$title', async ({ namespaceType }) => {
    factory({ namespaceType });
    await nextTick();
    expect(findEmptyListState().text()).toContain(namespaceType);
  });

  it('does display the "New policy" button for non-owners', async () => {
    factory();
    await nextTick();
    expect(findEmptyListState().attributes('primarybuttontext')).toBe('New policy');
  });

  it('does not display the "New policy" button for non-owners', async () => {
    factory({ disableScanPolicyUpdate: true });
    await nextTick();
    expect(findEmptyListState().attributes('primarybuttontext')).toBe('');
  });
});
