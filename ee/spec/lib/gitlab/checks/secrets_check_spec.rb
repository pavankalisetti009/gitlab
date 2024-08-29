# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretsCheck, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:secrets_check) { described_class.new(changes_access) }

  describe '#validate!' do
    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: false)
      end

      it_behaves_like 'skips the push check'
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: true)
      end

      context 'when project setting is disabled' do
        before do
          project.security_setting.update!(pre_receive_secret_detection_enabled: false)
        end

        it_behaves_like 'skips the push check'
      end

      context 'when project setting is enabled' do
        before do
          project.security_setting.update!(pre_receive_secret_detection_enabled: true)
        end

        context 'when instance is dedicated' do
          before do
            Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: true)
          end

          context 'when license is not ultimate' do
            it_behaves_like 'skips the push check'
          end

          context 'when license is ultimate' do
            before do
              stub_licensed_features(pre_receive_secret_detection: true)
            end

            context 'when deleting the branch' do
              # We instantiate the described class with delete_changes_access object to ensure
              # this spec example works as it uses repository.blank_ref to denote a branch deletion.
              subject(:secrets_check) { described_class.new(delete_changes_access) }

              it_behaves_like 'skips the push check'
            end

            it_behaves_like 'scan passed'
            it_behaves_like 'scan detected secrets'
            it_behaves_like 'scan detected secrets but some errors occured'
            it_behaves_like 'scan timed out'
            it_behaves_like 'scan failed to initialize'
            it_behaves_like 'scan failed with invalid input'
            it_behaves_like 'scan skipped due to invalid status'
            it_behaves_like 'scan skipped when a commit has special bypass flag'
            it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
          end
        end

        context 'when instance is not dedicated' do
          before do
            Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: false)
          end

          context 'when license is not ultimate' do
            it_behaves_like 'skips the push check'
          end

          context 'when license is ultimate' do
            before do
              stub_licensed_features(pre_receive_secret_detection: true)
            end

            # We do not need to duplicate the other tests that are also running
            # for Dedicated instances When we consolidate and no longer have to check
            # instance type, we should use the full suite of specs we're running for Dedicated.
            it_behaves_like 'scan detected secrets'

            context 'when feature flag is disabled' do
              before do
                stub_feature_flags(pre_receive_secret_detection_push_check: false)
              end

              it_behaves_like 'skips the push check'
            end
          end
        end
      end
    end
  end
end
