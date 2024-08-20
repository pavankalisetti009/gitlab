import { GlDisclosureDropdown, GlDrawer, GlLink, GlPopover, GlTable, GlTooltip } from '@gitlab/ui';
import { nextTick } from 'vue';
import * as urlUtils from '~/lib/utils/url_utility';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';
import { mockScanExecutionPoliciesResponse } from '../../mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from '../../mocks/mock_scan_result_policy_data';

const namespacePath = 'path/to/project/or/group';

describe('List component', () => {
  let wrapper;

  const factory =
    (mountFn = mountExtended) =>
    ({ props = {}, provide = {} } = {}) => {
      wrapper = mountFn(ListComponent, {
        propsData: {
          policiesByType: {
            [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
            [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
          },
          ...props,
        },
        provide: {
          disableScanPolicyUpdate: false,
          namespacePath,
          namespaceType: NAMESPACE_TYPES.PROJECT,
          ...provide,
        },
        stubs: {
          DrawerWrapper: stubComponent(DrawerWrapper, {
            props: {
              ...DrawerWrapper.props,
              ...GlDrawer.props,
            },
          }),
          NoPoliciesEmptyState: true,
        },
      });

      document.title = 'Test title';
      jest.spyOn(urlUtils, 'updateHistory');
    };
  const mountShallowWrapper = factory(shallowMountExtended);
  const mountWrapper = factory();

  const findActionCells = () => wrapper.findAllByTestId('policy-action-cell');
  const findDisclosureDropdown = (root) => root.findComponent(GlDisclosureDropdown);
  const findSourceFilter = () => wrapper.findByTestId('policy-source-filter');
  const findTypeFilter = () => wrapper.findByTestId('policy-type-filter');
  const findTable = () => wrapper.findComponent(GlTable);
  const findListComponentScope = () => wrapper.findComponent(ListComponentScope);
  const findStatusCells = () => wrapper.findAllByTestId('policy-status-cell');
  const findSourceCells = () => wrapper.findAllByTestId('policy-source-cell');
  const findTypeCells = () => wrapper.findAllByTestId('policy-type-cell');
  const findDrawer = () => wrapper.findByTestId('policyDrawer');
  const findScopeCells = () => wrapper.findAllByTestId('policy-scope-cell');
  const findTooltip = (root) => root.findComponent(GlTooltip);
  const findInheritedPolicyCell = (findMethod) => findMethod().at(1);
  const findNonInheritedPolicyCell = (findMethod) => findMethod().at(0);

  describe('initial state while loading', () => {
    it('renders closed editor drawer', () => {
      mountShallowWrapper();

      const editorDrawer = findDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props('open')).toBe(false);
    });

    it("sets table's loading state", () => {
      mountShallowWrapper({ props: { isLoadingPolicies: true } });

      expect(findTable().attributes('busy')).toBe('true');
    });
  });

  describe('initial state with data', () => {
    let rows;

    describe.each`
      rowIndex | expectedPolicyName                           | expectedPolicyType
      ${1}     | ${mockScanExecutionPoliciesResponse[0].name} | ${'Scan execution'}
      ${3}     | ${mockScanResultPoliciesResponse[0].name}    | ${'Merge request approval'}
    `('policy in row #$rowIndex', ({ rowIndex, expectedPolicyName, expectedPolicyType }) => {
      let row;

      beforeEach(() => {
        mountWrapper();
        rows = wrapper.findAll('tr');
        row = rows.at(rowIndex);
      });

      it(`renders ${expectedPolicyName} in the name cell`, () => {
        expect(row.findAll('td').at(1).text()).toBe(expectedPolicyName);
      });

      it(`renders ${expectedPolicyType} in the policy type cell`, () => {
        expect(row.findAll('td').at(2).text()).toBe(expectedPolicyType);
      });
    });

    it.each`
      type                | filterBy                                     | hiddenTypes
      ${'scan execution'} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION} | ${[POLICY_TYPE_FILTER_OPTIONS.APPROVAL]}
      ${'scan result'}    | ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL}       | ${[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION]}
    `('filtered by $type type', async ({ filterBy, hiddenTypes }) => {
      mountWrapper({ props: { selectedPolicyType: filterBy.value } });
      rows = wrapper.findAll('tr');
      await nextTick();

      expect(findTable().text()).toContain(filterBy.text);
      hiddenTypes.forEach((hiddenType) => {
        expect(findTable().text()).not.toContain(hiddenType.text);
      });
    });

    it('updates url when type filter is selected', () => {
      mountWrapper();
      rows = wrapper.findAll('tr');
      findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value.toLowerCase()}`,
        replace: true,
      });
    });
  });

  describe('policy drawer', () => {
    beforeEach(() => {
      mountWrapper();
    });

    it('updates the selected policy when `shouldUpdatePolicyList` changes to `true`', async () => {
      findTable().vm.$emit('row-selected', [mockScanExecutionPoliciesResponse[0]]);
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(mockScanExecutionPoliciesResponse[0]);
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(null);
    });

    it('does not update the selected policy when `shouldUpdatePolicyList` changes to `false`', async () => {
      expect(findDrawer().props('policy')).toEqual(null);
      wrapper.setProps({ shouldUpdatePolicyList: false });
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(null);
    });

    it.each`
      type                | policy                                  | policyType
      ${'scan execution'} | ${mockScanExecutionPoliciesResponse[0]} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}
      ${'scan result'}    | ${mockScanResultPoliciesResponse[0]}    | ${POLICY_TYPE_COMPONENT_OPTIONS.approval.value}
    `('renders opened editor drawer for a $type policy', async ({ policy, policyType }) => {
      mountWrapper();
      findTable().vm.$emit('row-selected', [policy]);
      await nextTick();
      const editorDrawer = findDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props()).toMatchObject({
        open: true,
        policy,
        policyType,
      });
    });

    it('should close drawer when new security project is selected', async () => {
      const scanExecutionPolicy = mockScanExecutionPoliciesResponse[0];

      mountWrapper();
      findTable().vm.$emit('row-selected', [scanExecutionPolicy]);
      await nextTick();

      expect(findDrawer().props('open')).toEqual(true);
      expect(findDrawer().props('policy')).toEqual(scanExecutionPolicy);

      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();

      expect(findDrawer().props('open')).toEqual(false);
      expect(findDrawer().props('policy')).toEqual(null);
    });
  });

  describe('columns', () => {
    describe('status', () => {
      beforeEach(() => {
        mountWrapper();
      });

      it('renders a checkmark icon for enabled policies', () => {
        const icon = findStatusCells().at(0).find('svg');

        expect(icon.exists()).toBe(true);
        expect(icon.classes()).toContain('gl-text-green-700');
        expect(icon.props()).toMatchObject({
          name: 'check-circle-filled',
          ariaLabel: 'The policy is enabled',
        });
      });

      it('renders a "Disabled" icon for screen readers for disabled policies', () => {
        const icon = findStatusCells().at(2).find('svg');

        expect(icon.exists()).toBe(true);
        expect(icon.attributes('class')).toContain('gl-text-gray-200');
        expect(icon.props('ariaLabel')).toBe('The policy is disabled');
      });

      describe('breaking changes icon', () => {
        const expectNoBreakingChangesIcon = () => {
          const icons = findStatusCells().at(0).findAll('svg');
          expect(icons.length).toBe(1);
          expect(icons.at(0).props('name')).toBe('check-circle-filled');
        };

        const expectRenderedBreakingChangesIcon = (expectedContent, expectedLink) => {
          const firstCell = findStatusCells().at(0);
          const icon = firstCell.findAll('svg');
          expect(icon.at(0).props('name')).toBe('check-circle-filled');
          expect(icon.at(0).classes()).toContain('gl-text-gray-200');
          expect(icon.at(1).props('name')).toBe('warning');

          expect(firstCell.findComponent(GlLink).attributes('href')).toBe(expectedLink);
          expect(firstCell.findComponent(GlPopover).text()).toBe(expectedContent);
        };

        it('does not render breaking changes icon when there are no deprecated properties', () => {
          mountWrapper();
          expectNoBreakingChangesIcon();
        });

        it('does not render breaking changes icon when policy type deprecated properties are not supported', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]: [
                  {
                    ...mockPipelineExecutionPoliciesResponse[0],
                    deprecatedProperties: ['test', 'test1'],
                  },
                ],
              },
            },
          });
          expectNoBreakingChangesIcon();
        });

        it('renders breaking changes icon when there are deprecated approval policy properties', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [
                  { ...mockScanResultPoliciesResponse[0], deprecatedProperties: ['test', 'test1'] },
                ],
              },
            },
          });
          expectRenderedBreakingChangesIcon(
            'You must edit the policy and replace the deprecated syntax (test, test1). For details on its replacement, see the policy documentation.',
            '/help/user/application_security/policies/merge_request_approval_policies#merge-request-approval-policies-schema',
          );
        });

        it('renders breaking changes icon when there are deprecated scan execution properties', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                  {
                    ...mockScanExecutionPoliciesResponse[0],
                    deprecatedProperties: ['test'],
                  },
                ],
              },
            },
          });
          expectRenderedBreakingChangesIcon(
            'You must edit the policy and replace the deprecated syntax (test). For details on its replacement, see the policy documentation.',
            '/help/user/application_security/policies/scan_execution_policies#scan-execution-policies-schema',
          );
        });
      });
    });

    describe('source', () => {
      it('renders when the policy is not inherited', () => {
        mountWrapper();
        expect(findNonInheritedPolicyCell(findSourceCells).text()).toBe('This project');
      });

      it('renders when the policy is inherited', () => {
        mountWrapper();
        expect(trimText(findInheritedPolicyCell(findSourceCells).text())).toBe(
          'Inherited from parent-group-name',
        );
      });

      it('renders inherited policy without namespace', () => {
        mountWrapper({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
        expect(trimText(findInheritedPolicyCell(findSourceCells).text())).toBe(
          'Inherited from parent-group-name',
        );
      });
    });

    describe('scope', () => {
      it.each([NAMESPACE_TYPES.GROUP, NAMESPACE_TYPES.PROJECT])(
        'renders policy scope column inside table on %s level',
        (namespaceType) => {
          mountWrapper({ provide: { namespaceType } });
          expect(findScopeCells()).toHaveLength(4);
          expect(findListComponentScope().exists()).toBe(true);
        },
      );
    });

    describe('actions', () => {
      beforeEach(() => {
        mountWrapper();
      });

      it('renders actions column', () => {
        expect(findActionCells()).toHaveLength(4);
      });

      it('renders non-inherited policy actions', () => {
        const policyCell = findNonInheritedPolicyCell(findActionCells);
        expect(findDisclosureDropdown(policyCell).exists()).toBe(true);
        expect(findDisclosureDropdown(policyCell).props('disabled')).toBe(false);
        expect(findTooltip(policyCell).exists()).toBe(false);
      });

      it('renders inherited policy actions', () => {
        const policyCell = findInheritedPolicyCell(findActionCells);
        expect(findDisclosureDropdown(policyCell).exists()).toBe(true);
        expect(findDisclosureDropdown(policyCell).props('disabled')).toBe(true);
        expect(findTooltip(policyCell).exists()).toBe(true);
      });

      it('renders items', () => {
        const policyCell = findNonInheritedPolicyCell(findActionCells);
        expect(findDisclosureDropdown(policyCell).props('items')).toEqual([
          {
            href: '/policies/policy-name/edit?type="scan_execution_policy"',
            text: 'Edit',
          },
        ]);
      });
    });
  });

  describe('filters', () => {
    describe('type', () => {
      beforeEach(() => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                mockScanExecutionPoliciesResponse[1],
              ],
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [mockScanResultPoliciesResponse[1]],
            },
          },
        });
        findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      });

      it('emits when the type filter is changed', () => {
        expect(wrapper.emitted('update-policy-type')).toEqual([
          [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value],
        ]);
      });

      it.each`
        value
        ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}
        ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}
      `('should select type filter value $value parameters are in url', ({ value }) => {
        mountWrapper({ props: { selectedPolicyType: value } });
        expect(findSourceFilter().props('value')).toBe(POLICY_SOURCE_OPTIONS.ALL.value);
        expect(findTypeFilter().props('value')).toBe(value);
      });

      it('updates url when type filter is selected', () => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
              [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
                mockPipelineExecutionPoliciesResponse,
            },
          },
        });

        findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value);

        expect(urlUtils.updateHistory).toHaveBeenCalledWith({
          title: 'Test title',
          url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value.toLowerCase()}`,
          replace: true,
        });
      });
    });

    describe('source', () => {
      beforeEach(() => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                mockScanExecutionPoliciesResponse[1],
              ],
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [mockScanResultPoliciesResponse[1]],
            },
          },
        });
        findSourceFilter().vm.$emit('input', POLICY_SOURCE_OPTIONS.INHERITED.value);
      });

      it('displays inherited policies only', () => {
        expect(findSourceCells()).toHaveLength(2);
        expect(trimText(findSourceCells().at(0).text())).toBe('Inherited from parent-group-name');
        expect(trimText(findSourceCells().at(1).text())).toBe('Inherited from parent-group-name');
      });

      it('updates url when source filter is selected', () => {
        expect(urlUtils.updateHistory).toHaveBeenCalledWith({
          title: 'Test title',
          url: `http://test.host/?source=${POLICY_SOURCE_OPTIONS.INHERITED.value.toLowerCase()}`,
          replace: true,
        });
      });

      it('displays inherited scan execution policies', () => {
        expect(trimText(findTypeCells().at(0).text())).toBe(
          POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
        );
      });

      it('displays inherited scan result policies', () => {
        expect(trimText(findTypeCells().at(1).text())).toBe(
          POLICY_TYPE_FILTER_OPTIONS.APPROVAL.text,
        );
      });

      it.each`
        value
        ${POLICY_SOURCE_OPTIONS.DIRECT.value}
        ${POLICY_SOURCE_OPTIONS.INHERITED.value}
      `('should select source filter value $value when parameters are in url', ({ value }) => {
        mountWrapper({ props: { selectedPolicySource: value } });
        expect(findSourceFilter().props('value')).toBe(value);
        expect(findTypeFilter().props('value')).toBe(POLICY_TYPE_FILTER_OPTIONS.ALL.value);
      });

      it('emits when the source filter is changed', () => {
        expect(wrapper.emitted('update-policy-source')).toEqual([
          [POLICY_SOURCE_OPTIONS.INHERITED.value],
        ]);
      });
    });
  });
});
