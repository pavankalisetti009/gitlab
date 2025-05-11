import { GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';

export const glFormGroupStub = stubComponent(GlFormGroup, {
  props: ['label', 'state', 'invalidFeedback'],
});

export const glRadioGroupStub = stubComponent(GlFormRadioGroup, {
  props: ['checked', 'state', 'options'],
});
