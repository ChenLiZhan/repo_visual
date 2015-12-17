require 'sidekiq'
require 'redis'
require 'mongo'
require 'httparty'
require_relative '../lib/repo_miner/lib/repos.rb'

class RepoWorker
  include Sidekiq::Worker

  def perform(step, repo_username, repo_name, gem_name, channel)
    client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')
    @gems = client[:gems]
    @github = Repos::GithubData.new(repo_username, repo_name)
    @rubygems = Repos::RubyGemsData.new(gem_name)
    @ruby_toolbox = Repos::RubyToolBoxData.new(gem_name)
    @stackoverflow = Repos::StackOverflow.new(gem_name)
    send("fetch_and_save_#{step}", repo_username, repo_name, gem_name)

    publish(channel, step)
  end

  def publish(channel, data)
    HTTParty.post('http://localhost:4567/faye', {
        :headers  => { 'Content-Type' => 'application/json' },
        :body    => {
            'channel'   => "/#{channel}",
            'data'      => data
        }.to_json
    })
  end

  def fetch_and_save_basic_information(repo_username, repo_name, gem_name)
    @gems.insert_one({
      'name'          => gem_name,
      'repo_name'     => repo_name,
      'repo_username' => repo_username,
      'created_at'    => DateTime.now
    })
  end

  def fetch_and_save_last_year_commit_activity(repo_username, repo_name, gem_name)
    commit_activity_last_year = @github.get_last_year_commit_activity
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"commit_activity_last_year" => commit_activity_last_year})
  end

  def fetch_and_save_contributors(repo_username, repo_name, gem_name)
    contributors = @github.get_contributors
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"contributors" => contributors})
  end

  def fetch_and_save_commits(repo_username, repo_name, gem_name)
    commits = @github.get_total_commits
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"commits" => commits})
  end

  def fetch_and_save_forks(repo_username, repo_name, gem_name)
    forks = @github.get_forks
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"forks" => forks})
  end

  def fetch_and_save_stars(repo_username, repo_name, gem_name)
    stars = @github.get_stars
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"stars" => stars})
  end

  def fetch_and_save_issues(repo_username, repo_name, gem_name)
    issues = @github.get_issues
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"issues" => issues})
  end

  def fetch_and_save_issues_info(repo_username, repo_name, gem_name)
    issues_info = @github.get_issues_info
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"issues_info" => issues_info})
  end

  def fetch_and_save_last_commit(repo_username, repo_name, gem_name)
    last_commit = @github.get_last_commits_days
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"last_commit" => last_commit})
  end

  def fetch_and_save_readme_word_count(repo_username, repo_name, gem_name)
    readme_word_count = @github.get_readme_word_count
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"readme_word_count" => readme_word_count})
  end

  def fetch_and_save_version_downloads(repo_username, repo_name, gem_name)
    version_downloads = @rubygems.get_version_downloads
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"version_downloads" => version_downloads})
  end

  def fetch_and_save_version_downloads_days(repo_username, repo_name, gem_name)
    version_downloads_days = @rubygems.get_version_downloads_trend
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"version_downloads_days" => version_downloads_days})
  end

  def fetch_and_save_dependencies(repo_username, repo_name, gem_name)
    dependencies = @rubygems.get_dependencies
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"dependencies" => dependencies})
  end

  def fetch_and_save_total_downloads(repo_username, repo_name, gem_name)
    total_downloads = @rubygems.get_total_downloads
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"total_downloads" => total_downloads})
  end

  def fetch_and_save_ranking(repo_username, repo_name, gem_name)
    ranking = @ruby_toolbox.get_ranking
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {"ranking" => ranking})
  end

  def fetch_and_save_questions(repo_username, repo_name, gem_name)
    questions, questions_word_count = @stackoverflow.get_questions
    document = @gems
                .find('name' => gem_name)
                .find_one_and_update("$set" => {
                    "questions" => questions,
                    "questions_word_count"  => questions_word_count
                  })
  end
end