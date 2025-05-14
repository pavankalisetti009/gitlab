# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistries::Maven::RegistriesController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_virtual_registries_maven_registries_path(group) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        it_behaves_like 'disallowed access to virtual registry'

        it 'pushes updateVirtualRegistry: false ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: false)
        end
      end

      context 'when user is group admin' do
        before_all do
          group.add_maintainer(user)
        end

        it 'pushes updateVirtualRegistry: true ability to frontend' do
          get_index

          expect(response.body).to have_pushed_frontend_ability(updateVirtualRegistry: true)
        end
      end
    end
  end

  describe 'GET #new' do
    subject { get new_group_virtual_registries_maven_registry_path(group) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is guest user' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'returning response status', :ok

        it_behaves_like 'disallowed access to virtual registry'
      end
    end
  end

  describe 'POST #create' do
    let(:params) { { maven_registry: { name: 'test registry', description: 'test description' } } }

    subject(:create_request) { post group_virtual_registries_maven_registries_path(group), params: params }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is guest user' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it 'redirects to show with success message' do
          expect(create_request).to redirect_to(group_virtual_registries_maven_registry_path(group,
            ::VirtualRegistries::Packages::Maven::Registry.last))
          expect(flash[:notice]).to eq('Maven virtual registry was created')
        end

        context 'with invalid parameters' do
          let(:params) { { maven_registry: { name: '' } } }

          it 'renders the new template with errors' do
            expect(create_request).to render_template(:new)
            expect(assigns(:maven_registry).errors[:name]).to be_present
          end
        end
      end
    end
  end

  describe 'GET #show' do
    let_it_be(:maven_registry) { create(:virtual_registries_packages_maven_registry, group:) }

    subject(:get_show) { get group_virtual_registries_maven_registry_path(group, maven_registry) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        it 'assigns the registry to @maven_registry' do
          get_show

          expect(assigns(:maven_registry)).to eq(maven_registry)
          expect(response).to render_template(:show)
        end

        context 'when the registry does not exist' do
          subject { get group_virtual_registries_maven_registry_path(group, id: non_existing_record_id) }

          it_behaves_like 'returning response status', :not_found
        end

        context 'when the registry belongs to another group' do
          let(:other_group) { create(:group) }
          let(:maven_registry) { create(:virtual_registries_packages_maven_registry, group: other_group) }

          it_behaves_like 'returning response status', :not_found
        end
      end
    end
  end
end
