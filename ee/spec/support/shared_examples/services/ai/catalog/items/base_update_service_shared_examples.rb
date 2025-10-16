# frozen_string_literal: true

RSpec.shared_examples Ai::Catalog::Items::BaseUpdateService do
  subject(:execute_service) { service.execute }

  shared_examples 'an error response' do |error|
    it 'returns an error response', :aggregate_failures do
      result = execute_service

      expect(result).to be_error
      expect(result.message).to match_array(Array(error))
      expect(result.payload[:item]).to eq(item)
    end

    it 'does not update the item' do
      expect { execute_service }.not_to change { item.reload.attributes }
    end

    it 'does not update the latest version' do
      expect { execute_service }.not_to change { latest_version.reload.attributes }
    end

    it 'does not trigger update_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { execute_service }
        .not_to trigger_internal_events('update_ai_catalog_item')
    end
  end

  describe '#execute', :freeze_time do
    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      it 'returns success response with item in payload', :aggregate_failures do
        result = execute_service

        expect(result).to be_success
        expect(result.payload[:item]).to eq(item)
      end

      it 'updates the item and its latest version', :aggregate_failures do
        execute_service

        expect(item.reload).to have_attributes(
          name: 'New name',
          description: 'New description',
          public: true
        )
        expect(latest_version.reload).to have_attributes(
          schema_version: item_schema_version,
          version: '1.1.0',
          release_date: Time.zone.now,
          definition: expected_updated_definition.stringify_keys
        )
        expect(item.latest_released_version).to eq(item.latest_version)
      end

      it 'triggers update_ai_catalog_item', :clean_gitlab_redis_shared_state do
        expect { execute_service }
         .to trigger_internal_events('update_ai_catalog_item')
         .with(user: user, project: project, additional_properties: { label: item.item_type })
         .and increment_usage_metrics('counts.count_total_update_ai_catalog_item')
      end

      context 'when version_bump is provided' do
        let(:params) { super().merge(version_bump: :patch) }

        it 'sets the version correctly' do
          execute_service

          expect(latest_version.reload).to have_attributes(
            schema_version: item_schema_version,
            version: '1.0.1',
            release_date: Time.zone.now,
            definition: expected_updated_definition.stringify_keys
          )
        end

        context 'when there is no previous released version' do
          before do
            item.update!(latest_released_version: nil)
            latest_released_version.destroy!
          end

          it 'sets the version to the default version' do
            execute_service

            expect(item.reload.latest_released_version).to eq(latest_version)
            expect(latest_version.reload).to have_attributes(
              schema_version: item_schema_version,
              version: '1.0.0',
              release_date: Time.zone.now,
              definition: expected_updated_definition.stringify_keys
            )
          end
        end
      end

      context 'when the latest version has been released' do
        before do
          latest_version.update!(release_date: 1.day.ago)
          item.update!(latest_released_version: latest_version)
        end

        it 'creates a new released version', :aggregate_failures do
          expect { execute_service }.to change { item.reload.versions.count }.by(1)
          expect(item.latest_version).not_to eq(latest_version)
          expect(item.latest_released_version).to eq(item.latest_version)
          expect(item.latest_version).to have_attributes(
            schema_version: item_schema_version,
            version: '2.0.0',
            release_date: Time.zone.now,
            definition: expected_updated_definition.stringify_keys
          )
        end

        it 'does not change the older version' do
          expect { execute_service }.not_to change { latest_version.reload.attributes }
        end

        context 'when version_bump is provided' do
          let(:params) { super().merge(version_bump: :patch) }

          it 'sets the version correctly' do
            execute_service

            expect(item.reload.latest_version).to have_attributes(
              schema_version: item_schema_version,
              version: '1.1.1',
              release_date: Time.zone.now,
              definition: expected_updated_definition.stringify_keys
            )
          end
        end

        context 'when the `ai_catalog_enforce_readonly_versions` flag is disabled' do
          before do
            stub_feature_flags(ai_catalog_enforce_readonly_versions: false)
          end

          it 'does not create a new version, and updates the existing version instead', :aggregate_failures do
            expect { execute_service }.not_to change { item.reload.versions.count }
            expect(item.latest_version).to eq(latest_version)
            expect(item.latest_released_version).to eq(latest_version)
            expect(item.latest_version).to have_attributes(
              schema_version: item_schema_version,
              version: '1.1.0',
              release_date: 1.day.ago,
              definition: expected_updated_definition.stringify_keys
            )
          end

          context 'when the version is not being released' do
            let(:params) { super().merge(release: false) }

            it 'does not unrelease the version', :aggregate_failures do
              expect { execute_service }.not_to change { item.reload.versions.count }
              expect(item.latest_version).to be_released
            end

            it 'does not change latest_released_version' do
              expect { execute_service }.not_to change { item.reload.latest_released_version }
            end
          end
        end

        context 'when the version is not being released' do
          let(:params) { super().merge(release: nil) }

          it 'creates a new unreleased version', :aggregate_failures do
            expect { execute_service }.to change { item.reload.versions.count }.by(1)
            expect(item.latest_version).not_to eq(latest_version)
            expect(item.latest_version.release_date).to be_nil
          end

          it 'does not change latest_released_version' do
            expect { execute_service }.not_to change { item.reload.latest_released_version }
          end
        end

        context 'when only item properties are updated' do
          let(:params) { { item: item, name: 'New name' } }

          it 'updates the item' do
            expect { execute_service }.to change { item.reload.name }.to('New name')
          end

          it 'does not create a new version' do
            expect { execute_service }.not_to change { item.reload.versions.count }
          end
        end
      end

      context 'when updated item is invalid' do
        let(:params) do
          {
            item: item,
            name: nil
          }
        end

        it_behaves_like 'an error response', "Name can't be blank"
      end

      context 'when updated latest version is invalid' do
        before do
          stub_const('Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION', nil)
          stub_const('Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION', nil)
          stub_const('Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION', nil)
        end

        it_behaves_like 'an error response', [
          "Latest version schema version can't be blank",
          'Latest version definition unable to validate definition'
        ]
      end

      context 'when only item properties are being updated' do
        let(:params) { { item: item, name: 'New name' } }

        it 'updates the item' do
          expect { execute_service }.to change { item.reload.name }.to('New name')
        end

        it 'does not update the latest version' do
          expect { execute_service }.not_to change { latest_version.reload.attributes }
        end
      end

      describe 'updating the latest version schema version' do
        before do
          allow_next_instance_of(JsonSchemaValidator) do |validator|
            allow(validator).to receive(:validate).and_return(true)
          end

          latest_version.update!(schema_version: 999)
        end

        it 'sets it to the current schema version' do
          expect { execute_service }.to change { latest_version.reload.schema_version }.to(item_schema_version)
        end

        context 'when the only change to the version is that it is being released' do
          let(:params) { { item: item, release: true } }

          it 'releases the version' do
            expect { execute_service }.to change { latest_version.reload.released? }.to(true)
          end

          it 'does not change the current schema version' do
            expect { execute_service }.not_to change { latest_version.reload.schema_version }
          end
        end

        context 'when only the item is being updated' do
          let(:params) { { item: item, name: 'New name' } }

          it 'does not change the current schema version' do
            expect { execute_service }.not_to change { latest_version.reload.schema_version }
          end
        end
      end

      describe 'when the item is soft-deleted' do
        before do
          item.update!(deleted_at: Time.current)
        end

        it_behaves_like 'an error response', 'You have insufficient permissions'
      end
    end
  end
end
