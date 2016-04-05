require 'sinatra/base'
require "sinatra/namespace"
require 'chartkick'
require 'mongo'
require 'httparty'
require 'date'
# require 'faye/websocket'
require 'faye'
require 'nokogiri'
require 'open-uri'
require 'sidekiq'
require 'digest/sha1'
require 'gems'
require 'json'

require_relative './helpers/helper.rb'
require_relative './workers/repo_worker.rb'
require_relative './config/initializers/sidekiq.rb'

class VizApp < Sinatra::Base
  register Sinatra::Namespace
  helpers VizHelper

  # Faye::WebSocket.load_adapter('puma')

  set :server, 'puma'
  client = Mongo::Client.new(ENV['mongodb_uri'], :max_pool_size => 10)
  HOST_API = "http://#{ENV['host']}/api/v1"

  before '/gems' do
    gem_list = []
    params[:page].nil? ? @page = 1 : @page = params[:page].to_i

    all_gem_list = client[:gems].find({:last_commit => {'$gte' => 0}})

    all_gem_list.skip((@page - 1) * 50).limit(50).each do |document|
      gem_list << {
        '_id'         => document['_id'],
        'name'        => document['name'],
        'created_at'  => document['created_at']
      }
    end

    @doc = gem_list
    @total_count = all_gem_list.count
    @total_pages = ((@total_count.to_f) / 50).round
  end

  ['/api/v1/*', '/dashboard/:id', '/rubygems/:id', '/github/:id', '/stackoverflow/:id'].each do |path|
    before path do
      if params[:id].nil?
        documents = []
        client[:gems].find.each do |document|
          documents << document
        end      

        @collection = client['gems']
        @doc = documents.last
      else
        documents = []
        client[:gems].find(:_id => BSON::ObjectId(params[:id])).each do |document|
          documents << document
        end

        @collection = client['gems']
        @doc = documents.last
      end
    end
  end

  get '/collect' do
    @channel = Digest::SHA1.hexdigest(headers.to_s)
    @current_authority = request.url.gsub(request.fullpath , '')
    erb :collect
  end

  post '/list_digging' do
    channel = params[:channel]

    all_gems = JSON.parse(HTTParty.get("#{HOST_API}/gems"))


    prepared_gem_groups = all_gems.take(5000).uniq.each_slice(150).to_a

    config = {
      'github_token' => ENV['github_token'],
      'github_password' => ENV['github_password'],
      'github_account' => ENV['github_account'],
      'user_agent' => ENV['user_agent'],
      'stackoverflow_token' => ENV['stackoverflow_token'],
      'current_authority' => request.url.gsub(request.fullpath , '')
    }

    prepared_gem_groups.each_with_index do |group, index|
      puts "---- Start processing Group #{index + 1} ----"
      group.each do |gem_info|
        repo_username, repo_name, gem_name = gem_info['repo_user'], gem_info['repo_name'], gem_info['gem_name'][0]
        puts "Gem: #{gem_name} #{repo_username}/#{repo_name}"
        RepoWorker.perform_async('basic_information', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('version_downloads', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('version_downloads_days', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('dependencies', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('total_downloads', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('ranking', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_async('questions', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'last_year_commit_activity', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'contributors', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'commits', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'commit_history', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'forks', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'stars', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'issues', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'issues_info', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'last_commit', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'readme_word_count', repo_username, repo_name, gem_name, channel, config)
        RepoWorker.perform_in(3300 * index, 'readme_raw_text', repo_username, repo_name, gem_name, channel, config)
      end
    end
  end

  post '/dig' do
    channel = params[:channel]
    repo_username = params[:repoUsername]
    repo_name = params[:repoName]
    gem_name = params[:gemName]

    config = {
      'github_token' => ENV['github_token'],
      'github_password' => ENV['github_password'],
      'github_account' => ENV['github_account'],
      'user_agent' => ENV['user_agent'],
      'stackoverflow_token' => ENV['stackoverflow_token'],
      'current_authority' => request.url.gsub(request.fullpath , '')
    }
    RepoWorker.perform_async('basic_information', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('last_year_commit_activity', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('contributors', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('commits', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('commit_history', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('forks', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('stars', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('issues', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('issues_info', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('last_commit', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('readme_word_count', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('readme_raw_text', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('version_downloads', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('version_downloads_days', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('dependencies', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('total_downloads', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('ranking', repo_username, repo_name, gem_name, channel, config)
    RepoWorker.perform_async('questions', repo_username, repo_name, gem_name, channel, config)
  end

  post '/search' do
    searched_gem_id = ''
    client[:gems].find('name' => params[:search_gem]).each do |doc|
      searched_gem_id = doc['_id']
    end

    if searched_gem_id === ''
      erb 'the gem is not exist or collected yet'
    else
      redirect to("/dashboard/#{searched_gem_id}")
    end
  end

  get '/stackoverflow/:id' do
    @question_views = HTTParty.get(HOST_API + "/stackoverflow/question_views?id=#{params[:id]}")
    @question_word_count = HTTParty.get(HOST_API + "/stackoverflow/question_titles?id=#{params[:id]}")
    erb :stackoverflow
  end


  get '/rubygems/:id' do
    @process_downloads_days = HTTParty.get(HOST_API + "/rubygems/version_downloads_days_process?id=#{params[:id]}")
    @version_downloads = HTTParty.get(HOST_API + "/rubygems/version_downloads?id=#{params[:id]}")
    @version_downloads_days = HTTParty.get(HOST_API + "/rubygems/version_downloads_days?id=#{params[:id]}")
    @version_downloads_stack = HTTParty.get(HOST_API + "/rubygems/version_downloads_stack?id=#{params[:id]}")
    @version_downloads_nest_drilldown = HTTParty.get(HOST_API + "/rubygems/version_downloads_nest?id=#{params[:id]}")
    erb :rubygems
  end

  get '/github/:id' do
    @issues_info = HTTParty.get(HOST_API + "/github/issues_info?id=#{params[:id]}")
    @commit_week_day = HTTParty.get(HOST_API + "/github/commit_week_day?id=#{params[:id]}")
    @commits_month_day = HTTParty.get(HOST_API + "/github/commits_month_day?id=#{params[:id]}")
    @readme_word_count = HTTParty.get(HOST_API + "/github/readme_word_count?id=#{params[:id]}")
    erb :github
  end

  get '/dashboard/:id' do
    @version_downloads_days_aggregate = HTTParty.get(HOST_API + "/rubygems/version_downloads_days_aggregate?id=#{params[:id]}")
    @version_downloads_nest_drilldown = HTTParty.get(HOST_API + "/rubygems/version_downloads_nest?id=#{params[:id]}")
    @commit_week_day = HTTParty.get(HOST_API + "/github/commit_week_day?id=#{params[:id]}").map do |data|
      [data[0], data[1]]
    end
    @commits_month_day = HTTParty.get(HOST_API + "/github/commits_month_day?id=#{params[:id]}")
    @issues_info = HTTParty.get(HOST_API + "/github/issues_info?id=#{params[:id]}")
    @issues_aggregate = HTTParty.get(HOST_API + "/github/issues_aggregate?id=#{params[:id]}")
    @readme_word_count = HTTParty.get(HOST_API + "/github/readme_word_count?id=#{params[:id]}")
    @commits_trend = HTTParty.get(HOST_API + "/github/commits_trend?id=#{params[:id]}")
    @question_views = HTTParty.get(HOST_API + "/stackoverflow/question_views?id=#{params[:id]}").map do |data|
      [data[0],data[1]]
    end
    @question_word_count = HTTParty.get(HOST_API + "/stackoverflow/question_titles?id=#{params[:id]}")

    erb :dashboard
  end

  get '/gems' do
    erb :gems
  end

  get '/' do
    erb :index
  end

  namespace '/api/v1' do
    get '/gems' do
      content_type :json
      all_gems = JSON.parse(File.read(File.dirname(__FILE__) + '/public/files/gems-81460.json'))

      all_gems.to_json
    end

    namespace '/rubygems' do
      get '/version_downloads_days_process' do
        content_type :json
        version_downloads_days_process = @doc['version_downloads_days'].map do |version|
          dates = {}
          @doc['version_downloads_days'].each do |version|
            version['downloads_date'].each do |value|
              dates[value[0]] = 0
            end
          end
          version['downloads_date'].each do |date, count|
            dates[date] = count 
          end
          {'number' => version['number'], 'downloads_date' => dates}
        end

        version_downloads_days_process.to_json
      end

      get '/version_downloads' do
        content_type :json
        version_downloads(@doc['version_downloads']).to_json
      end

      get '/version_downloads_days' do
        content_type :json
        version_downloads_days(@doc['version_downloads_days']).to_json
      end

      get '/version_downloads_days_aggregate' do
        content_type :json
        version_downloads_days_aggregate(@doc['version_downloads_days'], @doc['created_at']).to_json
      end

      get '/version_downloads_stack' do
        content_type :json
        version_downloads_stack(@doc['version_downloads']).to_json
      end

      get '/version_downloads_nest' do
        content_type :json
        version_downloads_nest(@doc['version_downloads']).to_json
      end
    end

    namespace '/github' do
      get '/issues_info' do
        content_type :json
        issues_info(@doc['issues_info']).to_json
      end

      get '/issues_aggregate' do
        content_type :json
        issues_aggregate(@doc['issues_info']).to_json
      end

      get '/commit_week_day' do
        content_type :json
        commit_week_day(@doc['commit_history']).to_json
      end

      get '/commits_month_day' do
        content_type :json
        commit_heatmap(@doc['commit_history']).to_json
      end

      get '/commits_trend' do
        content_type :json
        commits_trend(@doc['commit_history']).to_json
      end

      get '/readme_word_count' do
        content_type :json
        readme_word_count(@doc['readme_word_count']).to_json
      end
    end

    namespace '/stackoverflow' do
      get '/question_views' do
        content_type :json
        question_views(@doc['questions']).to_json
      end

      get '/question_titles' do
        content_type :json
        question_word_count = question_word_count(@doc['questions_word_count'])
        question_word_count.to_json
      end
    end
  end
end