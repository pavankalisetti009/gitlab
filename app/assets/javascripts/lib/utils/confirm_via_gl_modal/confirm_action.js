import Vue from 'vue';
import { InternalEvents } from '~/tracking';

export function createConfirmAction({ mountFn, destroyFn }) {
  return function confirmAction(
    message,
    {
      primaryBtnVariant,
      primaryBtnText,
      secondaryBtnVariant,
      secondaryBtnText,
      cancelBtnVariant,
      cancelBtnText,
      modalHtmlMessage,
      title,
      hideCancel,
      size,
      trackingEvent,
    } = {},
  ) {
    return new Promise((resolve) => {
      let confirmed = false;
      let component;

      const ConfirmAction = {
        name: 'ConfirmActionRoot',
        components: {
          ConfirmModal: () => import('./confirm_modal.vue'),
        },
        render(h) {
          return h(
            'confirm-modal',
            {
              props: {
                secondaryText: secondaryBtnText,
                secondaryVariant: secondaryBtnVariant,
                primaryVariant: primaryBtnVariant,
                primaryText: primaryBtnText,
                cancelVariant: cancelBtnVariant,
                cancelText: cancelBtnText,
                title,
                modalHtmlMessage,
                hideCancel,
                size,
              },
              on: {
                confirmed() {
                  confirmed = true;
                  if (trackingEvent) {
                    InternalEvents.trackEvent(trackingEvent.name, {
                      label: trackingEvent.label,
                      property: trackingEvent.property,
                      value: trackingEvent.value,
                    });
                  }
                },
                closed() {
                  destroyFn(component);
                  resolve(confirmed);
                },
              },
            },
            [message],
          );
        },
      };

      component = mountFn(ConfirmAction);
    });
  };
}

export const confirmAction = createConfirmAction({
  mountFn(Component) {
    return new Vue(Component).$mount();
  },
  destroyFn(instance) {
    instance.$destroy();
  },
});
