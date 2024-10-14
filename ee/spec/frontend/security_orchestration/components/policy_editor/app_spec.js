import { GlPath } from '@gitlab/ui';
import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';

describe('App component', () => {
  let wrapper;

  const findPolicySelection = () => wrapper.findComponent(PolicyTypeSelector);
  const findPolicyEditor = () => wrapper.findComponent(EditorWrapper);
  const findPath = () => wrapper.findComponent(GlPath);
  const findTitle = () => wrapper.findByTestId('title').text();

  const factory = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(App, {
      provide: {
        assignedPolicyProject: {},
        namespaceType: NAMESPACE_TYPES.GROUP,
        ...provide,
      },
      stubs: { GlPath: true },
    });
  };

  describe('when there is no type query parameter', () => {
    describe('projects', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
      });

      it('should display the title correctly', () => {
        expect(findTitle()).toBe('New policy');
      });

      it('should display the path items correctly', () => {
        expect(findPath().props('items')).toMatchObject([
          {
            selected: true,
            title: 'Step 1: Choose a policy type',
          },
          {
            disabled: true,
            selected: false,
            title: 'Step 2: Policy details',
          },
        ]);
      });

      it('should display the correct view', () => {
        expect(findPolicySelection().exists()).toBe(true);
        expect(findPolicyEditor().exists()).toBe(false);
      });
    });

    describe('groups', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      });

      it('should display the title correctly', () => {
        expect(findTitle()).toBe('New policy');
      });

      it('should display the correct view', () => {
        expect(findPolicySelection().exists()).toBe(true);
        expect(findPolicyEditor().exists()).toBe(false);
      });

      it('should display the path items correctly', () => {
        expect(findPath().props('items')).toMatchObject([
          {
            selected: true,
            title: 'Step 1: Choose a policy type',
          },
          {
            disabled: true,
            selected: false,
            title: 'Step 2: Policy details',
          },
        ]);
      });
    });

    describe('when existing policy selected', () => {
      it('should display correct title', () => {
        factory({
          provide: {
            existingPolicy: {
              id: 'policy-id',
              value: 'approval',
            },
          },
        });

        expect(findTitle()).toBe('Edit policy');
      });
    });
  });

  describe('when there is a type query parameter', () => {
    describe('approval', () => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter);
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            existingPolicy: {
              id: 'policy-id',
              value: 'approval',
            },
          },
        });
      });

      it('should display the title correctly', () => {
        expect(findTitle()).toBe('Edit merge request approval policy');
      });

      it('should not display the GlPath component when there is an existing policy', () => {
        expect(findPath().exists()).toBe(false);
      });

      it('should display the correct view according to the selected policy', () => {
        expect(findPolicySelection().exists()).toBe(false);
        expect(findPolicyEditor().exists()).toBe(true);
      });
    });

    describe('scan execution', () => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter);
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            existingPolicy: {
              id: 'policy-id',
              value: 'scanExecution',
            },
          },
        });
      });

      it('should display the title correctly', () => {
        expect(findTitle()).toBe('Edit scan execution policy');
      });
    });

    describe('invalid url parameter', () => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('invalid');
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            existingPolicy: {
              id: 'policy-id',
              value: 'scanResult',
            },
          },
        });
      });

      it('should display the title correctly', () => {
        expect(findTitle()).toBe('Edit policy');
      });
    });
  });
});
