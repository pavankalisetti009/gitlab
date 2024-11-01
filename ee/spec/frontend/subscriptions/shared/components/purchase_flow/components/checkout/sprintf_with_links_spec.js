import { mount } from '@vue/test-utils';
import { GlLink, GlSprintf } from '@gitlab/ui';
import SprintfWithLinks from 'ee/subscriptions/shared/components/purchase_flow/components/checkout/sprintf_with_links.vue';

describe('SprintfWithLinks', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    return mount(SprintfWithLinks, { propsData });
  };

  const findSprintf = () => wrapper.findComponent(GlSprintf);
  const findLinks = () => wrapper.findAllComponents(GlLink);

  const initialLinkObject = { firstLink: 'hitchhikersguide.org', lifeLink: '42.com' };

  describe('with links present in linkObject', () => {
    beforeEach(() => {
      wrapper = createComponent({
        message:
          'Go to %{firstLinkStart}this link%{firstLinkEnd} for the answer to %{lifeLinkStart}life%{lifeLinkEnd}',
        linkObject: initialLinkObject,
      });
    });

    it('shows correct message', () => {
      expect(findSprintf().text()).toEqual('Go to');
    });

    it('renders correct number of links', () => {
      expect(findLinks()).toHaveLength(2);
    });

    it('renders correct content in first link', () => {
      expect(findLinks().at(0).text()).toBe('this link');
      expect(findLinks().at(0).attributes('href')).toEqual(initialLinkObject.firstLink);
    });

    it('renders correct content in second link', () => {
      expect(findLinks().at(1).text()).toBe('life');
      expect(findLinks().at(1).attributes('href')).toEqual(initialLinkObject.lifeLink);
    });
  });

  describe('with links not present in linkObject', () => {
    beforeEach(() => {
      wrapper = createComponent({
        message:
          '%{towelLinkStart}A towel%{towelLinkEnd}, it says, is about the most massively useful thing an %{firstLinkStart}interstellar hitchhiker%{firstLinkEnd} can have',
        linkObject: initialLinkObject,
      });
    });

    it('shows correct message', () => {
      expect(findSprintf().text()).toEqual(
        '%{towelLinkStart}A towel%{towelLinkEnd}, it says, is about the most massively useful thing an',
      );
    });

    it('renders correct number of links', () => {
      expect(findLinks()).toHaveLength(1);
    });

    it('renders correct content', () => {
      expect(findLinks().at(0).text()).toBe('interstellar hitchhiker');
      expect(findLinks().at(0).attributes('href')).toEqual(initialLinkObject.firstLink);
    });
  });
});
