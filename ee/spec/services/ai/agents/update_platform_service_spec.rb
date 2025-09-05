# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Agents::UpdatePlatformService, :aggregate_failures, feature_category: :activation do
  describe '#execute' do
    let_it_be(:admin_user) { create(:admin) }
    let_it_be(:regular_user) { create(:user) }

    before_all do
      create(:application_setting, duo_availability: 'default_off', instance_level_ai_beta_features_enabled: false)
      create(:ai_settings, duo_core_features_enabled: false)
    end

    subject(:execute) { described_class.new(user, params).execute }

    context 'when user is authorized', :enable_admin_mode do
      let(:user) { admin_user }

      context 'with all parameters provided' do
        let(:params) do
          {
            duo_availability: 'default_on',
            instance_level_ai_beta_features_enabled: true,
            duo_core_features_enabled: true
          }
        end

        it { is_expected.to be_success }

        it 'updates all settings' do
          expect { execute }
            .to change {
              [
                ApplicationSetting.current.instance_level_ai_beta_features_enabled,
                ApplicationSetting.current.duo_availability,
                ::Ai::Setting.instance.duo_core_features_enabled
              ]
            }.from([false, :default_off, false]).to([true, :default_on, true])
        end
      end

      context 'with only duo_availability parameter' do
        let(:params) { { duo_availability: 'default_on' } }

        it { is_expected.to be_success }

        it 'updates only duo_availability' do
          expect { execute }
            .to change { ApplicationSetting.current.duo_availability }
                  .from(:default_off).to(:default_on)
                  .and not_change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                         .and not_change { ::Ai::Setting.instance.duo_core_features_enabled }
        end
      end

      context 'with only instance_level_ai_beta_features_enabled parameter' do
        let(:params) { { instance_level_ai_beta_features_enabled: true } }

        it { is_expected.to be_success }

        it 'updates only instance_level_ai_beta_features_enabled' do
          expect { execute }
            .to change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                  .from(false).to(true)
                  .and not_change { ApplicationSetting.current.duo_availability }
                         .and not_change { ::Ai::Setting.instance.duo_core_features_enabled }
        end
      end

      context 'with only duo_core_features_enabled parameter' do
        let(:params) { { duo_core_features_enabled: true } }

        it { is_expected.to be_success }

        it 'updates only duo_core_features_enabled' do
          expect { execute }
            .to change { ::Ai::Setting.instance.duo_core_features_enabled }
                  .from(false).to(true)
                  .and not_change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                         .and not_change { ApplicationSetting.current.duo_availability }
        end
      end

      context 'with duo_availability and instance_level_ai_beta_features_enabled' do
        let(:params) do
          {
            duo_availability: 'default_on',
            instance_level_ai_beta_features_enabled: true
          }
        end

        it { is_expected.to be_success }

        it 'updates both application settings' do
          expect { execute }
            .to change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                  .from(false).to(true)
                  .and change { ApplicationSetting.current.duo_availability }
                         .from(:default_off).to(:default_on)
                         .and not_change { ::Ai::Setting.instance.duo_core_features_enabled }
        end
      end

      context 'with duo_availability and duo_core_features_enabled' do
        let(:params) do
          {
            duo_availability: 'default_on',
            duo_core_features_enabled: true
          }
        end

        it { is_expected.to be_success }

        it 'updates both settings' do
          expect { execute }
            .to change { ApplicationSetting.current.duo_availability }
                  .from(:default_off).to(:default_on)
                  .and change { ::Ai::Setting.instance.duo_core_features_enabled }
                         .from(false).to(true)
                         .and not_change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
        end
      end

      context 'with instance_level_ai_beta_features_enabled and duo_core_features_enabled' do
        let(:params) do
          {
            instance_level_ai_beta_features_enabled: true,
            duo_core_features_enabled: true
          }
        end

        it { is_expected.to be_success }

        it 'updates both settings' do
          expect { execute }
            .to change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                  .from(false).to(true)
                  .and change { ::Ai::Setting.instance.duo_core_features_enabled }
                         .from(false).to(true)
                         .and not_change { ApplicationSetting.current.duo_availability }
        end
      end

      context 'with disabling parameters' do
        before do
          ApplicationSetting.current.update!(
            duo_availability: 'default_on',
            instance_level_ai_beta_features_enabled: true
          )
          ::Ai::Setting.instance.update!(duo_core_features_enabled: true)
        end

        context 'when disabling duo_availability' do
          let(:params) { { duo_availability: 'default_off' } }

          it { is_expected.to be_success }

          it 'disables duo_availability' do
            expect { execute }
              .to change { ApplicationSetting.current.duo_availability }
                    .from(:default_on).to(:default_off)
          end
        end

        context 'when disabling instance_level_ai_beta_features_enabled' do
          let(:params) { { instance_level_ai_beta_features_enabled: false } }

          it { is_expected.to be_success }

          it 'disables instance_level_ai_beta_features_enabled' do
            expect { execute }
              .to change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                    .from(true).to(false)
          end
        end

        context 'when disabling duo_core_features_enabled' do
          let(:params) { { duo_core_features_enabled: false } }

          it { is_expected.to be_success }

          it 'disables duo_core_features_enabled' do
            expect { execute }
              .to change { ::Ai::Setting.instance.duo_core_features_enabled }
                    .from(true).to(false)
          end
        end

        context 'when disabling all features' do
          let(:params) do
            {
              duo_availability: 'default_off',
              instance_level_ai_beta_features_enabled: false,
              duo_core_features_enabled: false
            }
          end

          it { is_expected.to be_success }

          it 'disables all features' do
            expect { execute }
              .to change { ApplicationSetting.current.duo_availability }
                    .from(:default_on).to(:default_off)
                    .and change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                           .from(true).to(false)
                           .and change { ::Ai::Setting.instance.duo_core_features_enabled }
                                  .from(true).to(false)
          end
        end
      end

      context 'with empty parameters' do
        let(:params) { {} }

        it { is_expected.to be_success }

        it 'does not change any settings' do
          expect { execute }
            .to not_change { ApplicationSetting.current.duo_availability }
                  .and not_change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                         .and not_change { ::Ai::Setting.instance.duo_core_features_enabled }
        end
      end

      context 'with blank values it fails validation' do
        let(:params) do
          {
            instance_level_ai_beta_features_enabled: nil,
            duo_core_features_enabled: ''
          }
        end

        it { is_expected.not_to be_success }

        it 'ignores blank values and does not change settings' do
          expect { execute }
            .to not_change { ApplicationSetting.current.duo_availability }
                  .and not_change { ApplicationSetting.current.instance_level_ai_beta_features_enabled }
                         .and not_change { ::Ai::Setting.instance.duo_core_features_enabled }
        end
      end

      context 'when application settings update fails' do
        let(:params) { { duo_availability: 'default_on', duo_core_features_enabled: true } }

        before do
          allow_next_instance_of(::ApplicationSettings::UpdateService) do |update_service|
            allow(update_service).to receive(:execute).and_return(false)
          end
        end

        it 'returns error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Failed to update Duo Agent Platform')
        end

        it 'does not update the settings' do
          expect { execute }.not_to change {
            [
              ApplicationSetting.current.reload.duo_availability,
              ApplicationSetting.current.reload.instance_level_ai_beta_features_enabled,
              ::Ai::Setting.instance.duo_core_features_enabled
            ]
          }
        end

        it 'logs error' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          execute
        end
      end

      context 'when ai settings update fails after application settings succeed' do
        let(:params) do
          {
            duo_availability: 'default_on',
            duo_core_features_enabled: true
          }
        end

        before do
          allow_next_instance_of(::Ai::DuoSettings::UpdateService) do |update_service|
            allow(update_service).to receive(:execute).and_return(ServiceResponse.error(message: 'AI settings error'))
          end
        end

        it 'returns error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Failed to update Duo Agent Platform')
        end

        it 'logs error' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          execute
        end
      end

      context 'when both updates fail' do
        let(:params) do
          {
            duo_availability: 'default_on',
            duo_core_features_enabled: true
          }
        end

        before do
          allow_next_instance_of(::ApplicationSettings::UpdateService) do |update_service|
            allow(update_service).to receive(:execute).and_return(false)
          end

          allow_next_instance_of(::Ai::DuoSettings::UpdateService) do |update_service|
            allow(update_service).to receive(:execute).and_return(ServiceResponse.error(message: 'AI settings error'))
          end
        end

        it 'returns error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Failed to update Duo Agent Platform')
        end

        it 'logs error' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          execute
        end
      end
    end

    context 'when user is not authorized' do
      let(:user) { regular_user }
      let(:params) { { duo_availability: 'default_on' } }

      it 'returns unauthorized response' do
        expect(execute).to be_error
        expect(execute.message).to eq('User not authorized to update Duo Agent Platform')
        expect(execute.reason).to eq(:access_denied)
      end

      it 'does not update the settings' do
        expect { execute }.not_to change {
          [
            ApplicationSetting.current.reload.instance_level_ai_beta_features_enabled,
            ApplicationSetting.current.reload.duo_availability,
            ::Ai::Setting.instance.duo_core_features_enabled
          ]
        }
      end
    end

    context 'when user is nil' do
      let(:user) { nil }
      let(:params) { { duo_availability: 'default_on' } }

      it 'returns unauthorized response' do
        expect(execute).to be_error
        expect(execute.message).to eq('User not authorized to update Duo Agent Platform')
        expect(execute.reason).to eq(:access_denied)
      end
    end
  end
end
