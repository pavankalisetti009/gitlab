import { GlForm } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';
import TestMavenUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/test_maven_upstream_button.vue';

describe('RegistryUpstreamForm', () => {
  let wrapper;

  const upstream = {
    id: 1,
    name: 'foo',
    url: 'https://example.com',
    description: 'bar',
    username: 'bax',
    cacheValidityHours: 0,
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(RegistryUpstreamForm, {
      propsData: props,
      provide,
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findByTestId('name-input');
  const findUpstreamUrlInput = () => wrapper.findByTestId('upstream-url-input');
  const findDescriptionInput = () => wrapper.findByTestId('description-input');
  const findUsernameInput = () => wrapper.findByTestId('username-input');
  const findPasswordInput = () => wrapper.findByTestId('password-input');
  const findCacheValidityHoursInput = () => wrapper.findByTestId('cache-validity-hours-input');
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findTestUpstreamButton = () => wrapper.findComponent(TestMavenUpstreamButton);

  beforeEach(() => {
    createComponent();
  });

  describe('renders', () => {
    it('renders Form', () => {
      expect(findForm().exists()).toBe(true);
    });

    describe('inputs', () => {
      it('renders Name input', () => {
        expect(findNameInput().exists()).toBe(true);
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().exists()).toBe(true);
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().exists()).toBe(true);
      });

      it('renders Username input', () => {
        expect(findUsernameInput().exists()).toBe(true);
      });

      it('renders Password input', () => {
        expect(findPasswordInput().exists()).toBe(true);
      });

      it('renders Cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(24);
      });
    });

    describe('inputs when upstream prop is set', () => {
      beforeEach(() => {
        createComponent({
          props: { upstream },
        });
      });

      it('renders Name input', () => {
        expect(findNameInput().props('value')).toBe('foo');
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().props('value')).toBe('https://example.com');
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().props('value')).toBe('bar');
      });

      it('renders Username input', () => {
        expect(findUsernameInput().props('value')).toBe('bax');
      });

      it('renders Password input', () => {
        expect(findPasswordInput().props('value')).toBe('');
        expect(findPasswordInput().props('placeholder')).toBe('*****');
      });

      it('renders Cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(0);
      });
    });

    describe('buttons', () => {
      it('renders Create upstream button', () => {
        expect(findSubmitButton().text()).toBe('Create upstream');
      });

      it('renders Cancel button', () => {
        expect(findCancelButton().text()).toBe('Cancel');
        expect(findCancelButton().props('href')).toBe('');
      });

      it('renders `Save changes` button when upstream exists', () => {
        createComponent({ props: { upstream } });
        expect(findSubmitButton().text()).toBe('Save changes');
      });

      it('sets upstreamPath to Cancel button href attribute when present', () => {
        createComponent({
          provide: {
            upstreamPath: 'upstream_path',
          },
        });
        expect(findCancelButton().props('href')).toBe('upstream_path');
      });
    });
  });

  describe('emits events', () => {
    it('emits submit event when form is submitted and form is valid', () => {
      createComponent({ props: { upstream } });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: 'https://example.com',
          description: 'bar',
          username: 'bax',
          cacheValidityHours: 0,
        }),
      );
    });

    it('does not emit a submit event when the form is not valid', () => {
      createComponent({ props: { upstream: { ...upstream, url: 'ftp://hello' } } });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');

      expect(Boolean(submittedEvent)).toBe(false);
    });

    it('emits cancel event when Cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(Boolean(wrapper.emitted('cancel'))).toBe(true);
      expect(wrapper.emitted('cancel')[0]).toEqual([]);
    });
  });

  describe('test upstream button', () => {
    it('renders Test upstream button component', () => {
      expect(findTestUpstreamButton().props()).toStrictEqual({
        disabled: true,
        upstreamId: null,
        url: '',
        username: '',
        password: '',
      });
    });

    it('enables button if valid URL is provided', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://gitlab.com');

      expect(findTestUpstreamButton().props('disabled')).toBe(false);
      expect(findTestUpstreamButton().props('username')).toBe('');
    });

    it('disables button if username is provided but password is not', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://gitlab.com');

      expect(findTestUpstreamButton().props('disabled')).toBe(false);

      await findUsernameInput().vm.$emit('input', 'username');

      expect(findTestUpstreamButton().props('disabled')).toBe(true);
    });

    describe('when upstream prop is set', () => {
      beforeEach(() => {
        createComponent({
          props: { upstream },
        });
      });

      it('renders Test upstream button component', () => {
        expect(findTestUpstreamButton().props()).toStrictEqual({
          disabled: false,
          upstreamId: upstream.id,
          url: upstream.url,
          username: upstream.username,
          password: '',
        });
      });
    });

    it('disables test upstream button component when the form is not valid', () => {
      createComponent({
        props: { upstream: { ...upstream, url: 'ftp://hello' } },
      });

      expect(findTestUpstreamButton().props('disabled')).toBe(true);
    });
  });
});
