class JekyllSiteGeneratorJob
  @queue = :default

  def self.perform(country_id, list_owner_screen_name, areas)
    database = SeePoliticiansTweet::App.database
    country = database[:countries].first(id: country_id)
    new(country, list_owner_screen_name, areas).generate
  end

  attr_reader :country
  attr_reader :areas

  def initialize(country, list_owner_screen_name, areas)
    @country = country
    @list_owner_screen_name = list_owner_screen_name
    @areas = areas
  end

  def templates_dir
    File.expand_path(File.join('..', '..', '..', 'jekyll', 'templates'), __FILE__)
  end

  def repo_dir
    File.expand_path(File.join('..', '..', '..', 'jekyll', 'repo'), __FILE__)
  end

  def generate
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        create_or_update_repo(dir)

        template = Tilt.new(File.join(templates_dir, '_config.yml.erb'))
        config_yml = template.render(
          self,
          country_name: country[:name],
          list_owner_screen_name: @list_owner_screen_name,
          base_url: country[:url]
        )
        File.open(File.join(dir, '_config.yml'), 'w') do |f|
          f.puts(config_yml)
        end
        template = Tilt.new(File.join(templates_dir, 'area.html.erb'))
        areas.each do |area|
          File.open(File.join(dir, '_areas', "#{area['list_slug']}.html"), 'w') do |f|
            f.puts(template.render(self, area))
          end
        end

        `git add .`
        author = "#{gh_client.login} <#{gh_client.emails.first[:email]}>"
        message = "Automated commit for #{country[:name]}"
        `git commit --author="#{author}" --message="#{message}"`
        `git push --quiet origin gh-pages`
      end
    end
  end

  def create_or_update_repo(dir)
    repo_name = country[:url].gsub('/', '')
    begin
      repo = gh_client.repository("seepoliticianstweet/#{repo_name}")
      `git clone --quiet #{clone_url(repo)} .`
    rescue Octokit::NotFound
      # Repository doesn't exist yet
      repo = gh_client.create_repository(
        repo_name,
        organization: 'seepoliticianstweet',
        homepage: "https://seepoliticianstweet.github.io/#{repo_name}"
      )
      `git init`
      `git symbolic-ref HEAD refs/heads/gh-pages`
      `git remote add origin #{clone_url(repo)}`
    end

    # Update files in repo
    FileUtils.cp_r(repo_dir + '/.', dir)
  end

  def clone_url(repo)
    repo_clone_url = URI.parse(repo.clone_url)
    repo_clone_url.user = gh_client.login
    repo_clone_url.password = gh_client.access_token
    repo_clone_url
  end

  def gh_client
    @gh_client ||= Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  end
end