import { GlProgressBar, GlCard } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GetStarted from 'ee/pages/projects/get_started/components/get_started.vue';
import SectionHeader from 'ee/pages/projects/get_started/components/section_header.vue';
import SectionBody from 'ee/pages/projects/get_started/components/section_body.vue';

describe('GetStarted', () => {
  let wrapper;

  const createSections = () => [
    {
      title: 'Section 1',
      description: 'Description 1',
      actions: [
        { id: 1, title: 'Action 1', completed: true },
        { id: 2, title: 'Action 2', completed: false },
      ],
    },
    {
      title: 'Section 2',
      description: 'Description 2',
      trialActions: [
        { id: 3, title: 'Trial Action 1', completed: true },
        { id: 4, title: 'Trial Action 2', completed: false },
      ],
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GetStarted, {
      propsData: {
        sections: createSections(),
        ...props,
      },
      stubs: {
        GlCard: { template: '<div><slot name="header" /><slot /></div>' },
      },
    });
  };

  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findSectionHeaders = () => wrapper.findAllComponents(SectionHeader);
  const findSectionBodies = () => wrapper.findAllComponents(SectionBody);
  const findTitle = () => wrapper.find('h2');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(findTitle().text()).toBe('Quick start');
    });

    it('renders a progress bar', () => {
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders a card for each section', () => {
      expect(findCards()).toHaveLength(2);
    });

    it('renders section headers', () => {
      expect(findSectionHeaders()).toHaveLength(2);
    });

    it('renders section bodies', () => {
      expect(findSectionBodies()).toHaveLength(2);
    });
  });

  describe('action counting', () => {
    it('correctly calculates total actions', () => {
      createComponent();
      expect(wrapper.vm.totalActions).toBe(4);
    });

    it('correctly calculates completed actions', () => {
      createComponent();
      expect(wrapper.vm.completedActions).toBe(2);
    });

    it('correctly calculates completion percentage', () => {
      createComponent();
      expect(wrapper.vm.completionPercentage).toBe(50);
    });

    it('handles sections without actions or trialActions', () => {
      createComponent({
        sections: [{ title: 'Empty Section', description: 'No actions' }],
      });
      expect(wrapper.vm.totalActions).toBe(0);
      expect(wrapper.vm.completedActions).toBe(0);
    });
  });

  describe('section expansion', () => {
    beforeEach(() => {
      createComponent();
    });

    it('expands the first section by default', () => {
      expect(wrapper.vm.expandedIndex).toBe(0);
      expect(wrapper.vm.isExpanded(0)).toBe(true);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });

    it('toggles expansion when a section header is clicked', async () => {
      // Toggle section 1 (should collapse it)
      await wrapper.vm.toggleExpand(0);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(0)).toBe(false);

      // Toggle section 2 (should expand it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(1);
      expect(wrapper.vm.isExpanded(0)).toBe(false);
      expect(wrapper.vm.isExpanded(1)).toBe(true);

      // Toggle section 2 again (should collapse it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });
  });
});
