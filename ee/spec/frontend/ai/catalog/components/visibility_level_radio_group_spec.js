import { GlFormRadio, GlFormRadioGroup, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components/visibility_level_radio_group.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

describe('VisibilityLevelRadioGroup', () => {
  let wrapper;

  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAllHelpPopovers = () => wrapper.findAllComponents(HelpPopover);

  const defaultProps = {
    id: '1',
    texts: {
      textPrivate: 'Private text',
      textPublic: 'Public text',
    },
    itemType: 'AGENT',
    value: VISIBILITY_LEVEL_PUBLIC,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(VisibilityLevelRadioGroup, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormRadio,
        GlSprintf,
      },
    });
  };

  describe('Visibility Level Radio Group', () => {
    it('emits the input event', () => {
      createWrapper();

      findFormRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PUBLIC);

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0][0]).toBe(VISIBILITY_LEVEL_PUBLIC);

      findFormRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PRIVATE);

      expect(wrapper.emitted('input')).toHaveLength(2);
      expect(wrapper.emitted('input')[1][0]).toBe(VISIBILITY_LEVEL_PRIVATE);
    });

    describe('popover', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders a popover for each visibility level', () => {
        expect(findAllHelpPopovers()).toHaveLength(2);
      });

      it('renders correct content for private popover', () => {
        const privatePopover = findAllHelpPopovers().at(0);
        expect(privatePopover.props('options')).toEqual({
          title: 'Private agent',
        });
        expect(privatePopover.findAll('strong').at(0).text()).toBe('A private agent:');
        expect(privatePopover.text()).toContain(
          'Is visible only to users with at least the Developer role for this project, and to users with the Owner role for the top-level group.',
        );
        expect(privatePopover.findAll('strong').at(1).text()).toBe('Private agents are best for:');
        expect(privatePopover.text()).toContain('Project-specific automation.');
      });

      it('renders correct content for public popover', () => {
        const publicPopover = findAllHelpPopovers().at(1);
        expect(publicPopover.props('options')).toEqual({
          title: 'Public agent',
        });
        expect(publicPopover.findAll('strong').at(0).text()).toBe('A public agent:');
        expect(publicPopover.text()).toContain('Is visible to all users.');
        expect(publicPopover.findAll('strong').at(1).text()).toBe('Public agents are best for:');
        expect(publicPopover.text()).toContain('Community contributions.');
        expect(publicPopover.text()).toContain('Anyone can see your prompts and settings.');
      });
    });
  });
});
