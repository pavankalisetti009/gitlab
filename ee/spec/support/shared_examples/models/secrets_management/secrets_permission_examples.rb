# frozen_string_literal: true

RSpec.shared_examples 'a secrets permission' do
  # Note: The including spec must define a `permission` subject that creates the base permission object

  it { is_expected.to validate_presence_of(:resource) }
  it { is_expected.to validate_presence_of(:principal_id) }
  it { is_expected.to validate_presence_of(:principal_type) }
  it { is_expected.to validate_presence_of(:permissions) }

  describe 'normalized_expired_at' do
    context 'when expired_at is present' do
      context 'with date-only format' do
        it 'normalizes it to string' do
          permission.expired_at = '2025-10-12'
          expect(permission.normalized_expired_at).to eq('2025-10-12T00:00:00Z')
        end
      end

      context 'with full datetime format' do
        it 'converts to UTC ISO8601 format' do
          permission.expired_at = '2025-10-12T15:30:00+02:00'
          expect(permission.normalized_expired_at).to eq('2025-10-12T13:30:00Z')
        end
      end
    end

    context 'when expired_at is blank' do
      it 'returns nil' do
        permission.expired_at = ''
        expect(permission.normalized_expired_at).to be_nil
      end
    end

    context 'when expired_at is nil' do
      it 'returns nil' do
        permission.expired_at = nil
        expect(permission.normalized_expired_at).to be_nil
      end
    end
  end

  describe 'expired_at validation' do
    using RSpec::Parameterized::TableSyntax

    where(:case_name, :expired_at_input, :valid, :error_msg) do
      # --- valid
      'future ISO8601 (UTC)'        | 5.days.from_now.utc.iso8601.to_s       | true  | nil
      'future only date      '      | 2.days.from_now.to_date.iso8601.to_s   | true  | nil
      'blank allowed'               | ''                                     | true  | nil
      'nil allowed'                 | nil                                    | true  | nil

      # --- invalid: past time
      'past ISO8601 (UTC)'          | 1.day.ago.utc.iso8601.to_s             | false | 'must be in the future'
      'date-only in the past'       | '2025-01-30'                           | false | 'must be in the future'

      # --- invalid: bad formats
      'bad month'                   | '2025-13-01T00:00:00Z'                 | false | 'must be RFC3339'
      'nonsense'                    | 'not-a-date'                           | false | 'must be RFC3339'
    end

    with_them do
      it 'validates' do
        permission.expired_at = expired_at_input

        if valid
          expect(permission).to be_valid
        else
          expect(permission).to be_invalid
          expect(permission.errors[:expired_at].join).to include(error_msg)
        end
      end
    end
  end

  describe 'common validations' do
    it 'is valid with valid attributes' do
      expect(permission).to be_valid
    end

    it 'validates non-empty permissions includes read' do
      permission.permissions = ['create']
      expect(permission).not_to be_valid
      expect(permission.errors[:permissions]).to include("must include read")
    end

    it 'validates principal_type is valid' do
      permission.principal_type = 'InvalidType'
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_type]).to include('must be one of: User, Role, Group, MemberRole')
    end

    it 'validates permissions are valid' do
      permission.permissions = ['foo']
      expect(permission).not_to be_valid
      expect(permission.errors[:permissions]).to include('contains invalid permission: foo')
    end

    it 'validates role_id when principal_type is Role' do
      permission.principal_type = 'Role'
      permission.principal_id = 999 # Invalid role ID
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_id][0])
        .to match(/must be one of: reporter \(20\), developer \(30\), maintainer \(40\)/)
    end
  end

  describe 'User principal validation' do
    context 'when principal_type is User' do
      it 'validates successfully when the user is a member' do
        expect(permission).to be_valid
      end

      it 'is invalid when user does not exist' do
        permission.principal_id = User.count + 1
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id]).to include('user does not exist')
      end
    end
  end

  describe 'Group principal validation' do
    context 'when principal_type is Group' do
      it 'is invalid when group does not exist' do
        permission.principal_type = 'Group'
        permission.principal_id = Group.count + 1
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id]).to include('group does not exist')
      end
    end
  end
end
