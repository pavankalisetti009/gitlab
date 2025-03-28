# frozen_string_literal: true

class DataSeeder
  GROUP_CONFIGS = [
    { plan: :ultimate }, {
      plan: :ultimate,
      add_on: { name: :duo_enterprise }
    }, {
      plan: :ultimate,
      add_on: { name: :duo_enterprise, expired: true }
    }, {
      plan: :premium
    }, {
      plan: :premium,
      add_on: { name: :code_suggestions }
    }, {
      plan: :premium,
      expired: true,
      add_on: { name: :code_suggestions }
    }
  ].freeze

  def seed
    return @logger.info "Env must be setup to simulate SaaS" unless Gitlab.ee?

    team = fetch_team
    groups = GROUP_CONFIGS.map do |uc|
      group = create(:group_with_plan, params_for(uc))
      add_team_as_owners(group, team)

      next group unless uc[:add_on].present?

      add_on_id = GitlabSubscriptions::AddOn.find_by(name: uc.dig(:add_on, :name)).id # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn

      # TODO: build+save! works here but create causes a unique name validation error (they should be equivalent)
      build(:gitlab_subscription_add_on_purchase, uc[:add_on][:expired] ? :expired : :active, namespace: group,
        subscription_add_on_id: add_on_id).save!

      group
    end

    @logger.info "\n\nGroups created:\n\n"
    groups.each do |g|
      name = g.name[@group.name.length..]
      @logger.info "\t#{name} → //#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/groups/#{g.path}\n"
    end
  end

  private

  def params_for(uc)
    name = namespace_name(uc)
    params = { name: "#{@group.name} #{name.titlecase}", path: "#{@group.path}-#{name.parameterize}",
               plan: "#{uc[:plan]}_plan" }
    params.merge!({ trial: true, trial_starts_on: 10.days.ago, trial_ends_on: 1.day.ago }) if uc[:expired]
    params
  end

  def namespace_name(uc)
    [uc[:plan], uc[:trial] && "trial", uc[:expired] && "expired", uc.dig(:add_on, :name),
      uc.dig(:add_on, :trial) && "trial", uc.dig(:add_on, :expired) && "expired"].compact.join(" ")
  end

  def add_team_as_owners(namespace, team)
    team.each do |team_member|
      user = User.find_by(username: team_member) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
      next unless user

      namespace.add_owner(user)
    end
  end

  def fetch_team
    response = Faraday.get('https://about.gitlab.com/company/team/')

    return @logger.info "Fetching team members page failed" unless response.status == 200

    doc = Nokogiri::HTML(response.body)
    doc.css('div.member').filter_map do |div|
      team_name = div.css('h5').text.strip

      div.css('a.member-id').first['href'][1..] if team_name.include?('Growth: Acquisition')
    end
  end
end
