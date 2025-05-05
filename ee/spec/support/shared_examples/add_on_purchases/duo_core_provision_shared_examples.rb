# frozen_string_literal: true

RSpec.shared_examples 'does not change namespace Duo Core features setting' do
  where(:existing_setting) do
    [true, false, nil]
  end

  with_them do
    before do
      namespace.namespace_settings.update!(duo_nano_features_enabled: existing_setting) unless existing_setting.nil?
    end

    it 'does not change namespace Duo Core features setting' do
      expect { subject }
        .not_to change { namespace.namespace_settings.reload.duo_nano_features_enabled }
        .from(existing_setting)
    end
  end
end

RSpec.shared_examples 'enables DuoCore automatically only if customer has not chosen DuoCore setting for namespace' do
  it 'enables Duo Core automatically if customer has not chosen DuoCore setting on this namespace' do
    expect { subject }
      .to change { namespace.namespace_settings.reload.duo_nano_features_enabled }
      .from(nil).to(true)
  end

  context 'when customer has chosen DuoCore setting on this namespace' do
    [true, false].each do |customer_setting|
      it 'does not change existing setting' do
        namespace.namespace_settings.update!(duo_nano_features_enabled: customer_setting)

        expect { subject }.not_to change { namespace.namespace_settings.reload.duo_nano_features_enabled }
      end
    end
  end

  context 'when feature flag auto_enable_duo_core_settings is disabled' do
    before do
      stub_feature_flags(auto_enable_duo_core_settings: false)
    end

    it_behaves_like 'does not change namespace Duo Core features setting'
  end
end
