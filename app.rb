require 'sinatra/base'
require 'chartkick'
require 'mongo'
require 'httparty'
require 'date'
require 'faye/websocket'
require_relative './helpers/helper.rb'
require_relative './lib/repos.rb'

class VizApp < Sinatra::Base
  Faye::WebSocket.load_adapter('puma')
  set :server, 'puma'
  client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')

  helpers VizHelper
  
  ['/rubygems/?:id?', '/github/?:id?', '/stackoverflow/?:id?'].each do |path|
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
    @question_views = question_views(@doc['questions']).to_json
    @question_word_count = question_word_count(client['gems']).to_json
    #puts @question_word_count
    #@readme_word_count = HTTParty.get('http://localhost:4567/api/v1/stackoverflow/readme_word_count')
    #puts @readme_word_count
    erb :stackoverflow
  end


  get '/rubygems/?:id?' do
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

    @process_downloads_days = version_downloads_days_process
    @version_downloads = version_downloads(@doc['version_downloads'])
    @version_downloads_days = version_downloads_days(@doc['version_downloads_days'])
    @version_downloads_stack = version_downloads_stack(@doc['version_downloads'])
    @version_downloads_nest_drilldown = version_downloads_nest(@doc['version_downloads'])
    erb :rubygems
  end

  get '/github/?:id?' do
    @issues_info = issues_info(@doc['issues_info'])
    @commit_week_day = commit_week_day(@doc['commit_activity_last_year'])
    @commits_month_day = commit_heatmap(@doc['commit_activity_last_year'])
    @readme_word_count = readme_word_count(@doc['readme_word_count'])
    erb :github
  end

  get '/?:id?' do
    @id = params[:id]
    erb :index
  end
end