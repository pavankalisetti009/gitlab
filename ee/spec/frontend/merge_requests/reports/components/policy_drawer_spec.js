import { mountExtended } from 'helpers/vue_test_utils_helper';
import PolicyDrawer from 'ee/merge_requests/reports/components/policy_drawer.vue';

const createMockPolicy = (data = {}) => {
  return {
    enabled: true,
    name: 'policy name',
    description: '',
    yaml: null,
    actionApprovers: [
      {
        allGroups: [],
        roles: [],
        users: [],
      },
    ],
    source: {
      namespace: {
        name: 'Project',
        webUrl: '/namespace/project',
      },
    },
    ...data,
  };
};

describe('Merge request reports policy drawer component', () => {
  let wrapper;

  const findSecurityPolicy = () => wrapper.findByTestId('security-policy');
  const findPipeline = () => wrapper.findByTestId('security-pipeline');

  function createComponent(propsData = {}) {
    wrapper = mountExtended(PolicyDrawer, {
      propsData: {
        open: false,
        targetBranch: 'main',
        sourceBranch: 'feature',
        ...propsData,
      },
    });
  }

  it('does not render content when not opened', () => {
    createComponent();

    expect(findSecurityPolicy().exists()).toBe(false);
  });

  it('does not render content when opened with no policy', () => {
    createComponent({ open: true });

    expect(findSecurityPolicy().exists()).toBe(false);
  });

  it('renders content when opened with policy', () => {
    createComponent({ open: true, policy: createMockPolicy() });

    expect(findSecurityPolicy().exists()).toBe(true);
  });

  it('renders pipeline ID', () => {
    createComponent({
      open: true,
      policy: createMockPolicy(),
      pipeline: { updatedAt: '2024-01-01', iid: '1' },
    });

    expect(findPipeline().text()).toContain('in pipeline #1');
  });
});
