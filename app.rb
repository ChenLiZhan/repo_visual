require 'sinatra/base'
require "sinatra/namespace"
require 'chartkick'
require 'mongo'
require 'httparty'
require 'date'
require 'faye/websocket'
require_relative './helpers/helper.rb'
require_relative './lib/repo_miner/lib/repos.rb'

class VizApp < Sinatra::Base
  register Sinatra::Namespace
  helpers VizHelper

  Faye::WebSocket.load_adapter('puma')
  set :server, 'puma'
  client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')
  HOST_API = 'http://localhost:4567/api/v1'

  before '/gems' do
    documents = []
    client[:gems].find.each do |document|
      documents << document
    end      

    @collection = client['gems']
    @doc = documents
  end

  ['/api/v1/*', '/dashboard/?:id?', '/rubygems/?:id?', '/github/?:id?', '/stackoverflow/?:id?'].each do |path|
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

  get '/communicate' do
    tasks = %w['last_year_commit_activity', 'contributors', 
      'total_commits', 'forks', 'stars', 'issues', 'issues_info',
      'last_commits_days', 'readme_word_count', 'version_downloads',
      'version_downloads_trend', 'dependencies', 'total_downloads',
      'ranking', 'questions']

    if Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on(:open) do |event|
        puts 'On Open'
      end

      gems = {}
      
      ws.on(:message) do |msg|
        step = msg.data.match(/^\d+/)
        if step.nil?
            username, gem_name = msg.data.split(' ')
            @github = Repos::GithubData.new(username, gem_name)
            @rubygems = Repos::RubyGemsData.new(gem_name)
            @ruby_toolbox = Repos::RubyToolBoxData.new(gem_name)
            @stackoverflow = Repos::StackOverflow.new(gem_name)
            gems['name'] = gem_name
            ws.send("There are #{tasks.length} tasks to be done")
        else
          case step.to_s.to_i
            when 1
              gems['commit_activity_last_year'] = @github.get_last_year_commit_activity    
              ws.send(1)
            when 2
              gems['contributors'] = @github.get_contributors
              ws.send(2)
            when 3
              gems['commits'] = @github.get_total_commits
              ws.send(3)
            when 4
              gems['forks'] = @github.get_forks
              ws.send(4)
            when 5
              gems['stars'] = @github.get_stars
              ws.send(5)
            when 6
              gems['issues'] = @github.get_issues
              ws.send(6)
            when 7
              gems['issues_info'] = @github.get_issues_info
              ws.send(7)
            when 8
              gems['last_commit'] = @github.get_last_commits_days
              ws.send(8)
            when 9
              gems['readme_word_count'] = @github.get_readme_word_count
              ws.send(9)
            when 10
              gems['version_downloads'] = @rubygems.get_version_downloads
              ws.send(10)
            when 11
              gems['version_downloads_days'] = @rubygems.get_version_downloads_trend
              ws.send(11)
            when 12
              gems['dependencies'] = @rubygems.get_dependencies
              ws.send(12)
            when 13
              gems['total_downloads'] = @rubygems.get_total_downloads
              ws.send(13)
            when 14
              gems['ranking'] = @ruby_toolbox.get_ranking
              ws.send(14)
            when 15
              gems['questions'] = @stackoverflow.get_questions
              gems['created_at'] = DateTime.now
              ws.send(15)
            when 16
              puts gems
              id = client[:gems].insert_one(gems).inserted_id
              ws.send(id.to_s)
          end
        end
      end

      ws.on(:close) do |event|
        puts 'On Close'
      end

      ws.rack_response
    else
      erb :communicate
    end
  end

  get '/stackoverflow/?:id?' do
    if params[:id].nil?
      @question_views = HTTParty.get(HOST_API + '/stackoverflow/question_views')
      @question_word_count = HTTParty.get(HOST_API + '/stackoverflow/question_titles')
      #puts @question_word_count
      #@readme_word_count = HTTParty.get('http://localhost:4567/api/v1/stackoverflow/readme_word_count')
      #puts @readme_word_count
    else
      @question_views = HTTParty.get(HOST_API + "/stackoverflow/question_views?id=#{params[:id]}")
      @question_word_count = HTTParty.get(HOST_API + "/stackoverflow/question_titles?id=#{params[:id]}")
    end
    erb :stackoverflow
  end


  get '/rubygems/?:id?' do
    if params[:id].nil?
      @process_downloads_days = HTTParty.get(HOST_API + '/rubygems/version_downloads_days_process')
      @version_downloads = HTTParty.get(HOST_API + '/rubygems/version_downloads')
      @version_downloads_days = HTTParty.get(HOST_API + '/rubygems/version_downloads_days')
      @version_downloads_stack = HTTParty.get(HOST_API + '/rubygems/version_downloads_stack')
      @version_downloads_nest_drilldown = HTTParty.get(HOST_API + '/rubygems/version_downloads_nest')
    else
      @process_downloads_days = HTTParty.get(HOST_API + "/rubygems/version_downloads_days_process?id=#{params[:id]}")
      @version_downloads = HTTParty.get(HOST_API + "/rubygems/version_downloads?id=#{params[:id]}")
      @version_downloads_days = HTTParty.get(HOST_API + "/rubygems/version_downloads_days?id=#{params[:id]}")
      @version_downloads_stack = HTTParty.get(HOST_API + "/rubygems/version_downloads_stack?id=#{params[:id]}")
      @version_downloads_nest_drilldown = HTTParty.get(HOST_API + "/rubygems/version_downloads_nest?id=#{params[:id]}")
    end
    erb :rubygems
  end

  get '/github/?:id?' do
    if params[:id].nil?
      @issues_info = HTTParty.get(HOST_API + '/github/issues_info')
      @commit_week_day = HTTParty.get(HOST_API + '/github/commit_week_day')
      @commits_month_day = HTTParty.get(HOST_API + '/github/commits_month_day')
      @readme_word_count = HTTParty.get(HOST_API + '/github/readme_word_count')
    else
      @issues_info = HTTParty.get(HOST_API + "/github/issues_info?id=#{params[:id]}")
      @commit_week_day = HTTParty.get(HOST_API + "/github/commit_week_day?id=#{params[:id]}")
      @commits_month_day = HTTParty.get(HOST_API + "/github/commits_month_day?id=#{params[:id]}")
      @readme_word_count = HTTParty.get(HOST_API + "/github/readme_word_count?id=#{params[:id]}")
    end
    erb :github
  end

  get '/dashboard/?:id?' do
    if params[:id].nil?
      @version_downloads_days_aggregate = HTTParty.get(HOST_API + '/rubygems/version_downloads_days_aggregate')
      @version_downloads_nest_drilldown = HTTParty.get(HOST_API + '/rubygems/version_downloads_nest')
      @commit_week_day = HTTParty.get(HOST_API + '/github/commit_week_day').map do |data|
        [data[0], data[1]]
      end
      @commits_month_day = HTTParty.get(HOST_API + '/github/commits_month_day')
      @issues_info = HTTParty.get(HOST_API + '/github/issues_info')
      @readme_word_count = HTTParty.get(HOST_API + '/github/readme_word_count')
      @commits_trend = HTTParty.get(HOST_API + '/github/commits_trend')
    else
      @version_downloads_days_aggregate = HTTParty.get(HOST_API + "/rubygems/version_downloads_days_aggregate?id=#{params[:id]}")
      @version_downloads_nest_drilldown = HTTParty.get(HOST_API + "/rubygems/version_downloads_nest?id=#{params[:id]}")
      @commit_week_day = HTTParty.get(HOST_API + "/github/commit_week_day?id=#{params[:id]}").map do |data|
        [data[0], data[1]]
      end
      @commits_month_day = HTTParty.get(HOST_API + "/github/commits_month_day?id=#{params[:id]}")
      @issues_info = HTTParty.get(HOST_API + "/github/issues_info?id=#{params[:id]}")
      @readme_word_count = HTTParty.get(HOST_API + "/github/readme_word_count?id=#{params[:id]}")
      @commits_trend = HTTParty.get(HOST_API + "/github/commits_trend?id=#{params[:id]}")
    end
    erb :dashboard
  end

  get '/gems' do
    erb :gems
  end

  get '/?:id?' do
    @id = params[:id]
    erb :index
  end

  namespace '/api/v1' do
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
        version_downloads_days_aggregate(@doc['version_downloads_days']).to_json
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

      get '/commit_week_day' do
        content_type :json
        commit_week_day(@doc['commit_activity_last_year']).to_json
      end

      get '/commits_month_day' do
        content_type :json
        commit_heatmap(@doc['commit_activity_last_year']).to_json
      end

      get '/commits_trend' do
        content_type :json
        commits_trend(@doc['commit_activity_last_year']).to_json
      end

      get '/readme_word_count' do
        content_type :json
        readme_word_count(@doc['readme_word_count']).to_json
      end
    end

    namespace 'stackoverflow' do
      get '/question_views' do
        content_type :json
        question_views = question_views(@doc['questions'])
        question_views.to_json
      end

      get '/question_titles' do
        content_type :json
        question_word_count = question_word_count(client['gems'])
        question_word_count.to_json
      end
    end
  end
end