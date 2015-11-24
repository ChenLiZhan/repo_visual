require 'sinatra/base'
require 'chartkick'
require 'mongo'
require 'httparty'
require 'date'
require_relative './helpers/helper.rb'

class VizApp < Sinatra::Base
  client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')
  helpers VizHelper
  
  before do
    documents = []
    client[:gems].find.each do |document|
      documents << document
    end      

    @doc = documents.last
  end


  get '/' do
    erb :index
  end

  get '/rubygems' do
    @process_downloads_days = HTTParty.get('http://localhost:4567/api/v1/rubygems/version_downloads_days_process')
    @version_downloads = HTTParty.get('http://localhost:4567/api/v1/rubygems/version_downloads')
    @version_downloads_days = HTTParty.get('http://localhost:4567/api/v1/rubygems/version_downloads_days')
    @version_downloads_stack = HTTParty.get('http://localhost:4567/api/v1/rubygems/version_downloads_stack')
    @version_downloads_nest_drilldown = HTTParty.get('http://localhost:4567/api/v1/rubygems/version_downloads_nest')
    erb :rubygems
  end

  get '/github' do
    @issues_info = HTTParty.get('http://localhost:4567/api/v1/github/issues_info')
    @commit_week_day = HTTParty.get('http://localhost:4567/api/v1/github/commit_week_day')
    @commits_month_day = HTTParty.get('http://localhost:4567/api/v1/github/commits_month_day')
    erb :github
  end

  get '/api/v1/rubygems/version_downloads_days' do
    content_type :json
    version_downloads_days = version_downloads_days(@doc['version_downloads_days'])
    version_downloads_days.to_json
  end

  get '/api/v1/rubygems/version_downloads_days_process' do
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

  get '/api/v1/rubygems/version_downloads' do
    content_type :json
    version_downloads = version_downloads(@doc['version_downloads'])
    version_downloads.to_json
  end

  get '/api/v1/rubygems/version_downloads_stack' do
    content_type :json
    version_downloads_data = version_downloads_stack(@doc['version_downloads'])
    version_downloads_data.to_json
  end

  get '/api/v1/rubygems/version_downloads_nest' do
    content_type :json
    version_downloads_nest = version_downloads_nest(@doc['version_downloads'])
    version_downloads_nest.to_json
  end

  get '/api/v1/github/issues_info' do
    content_type :json
    issues_info = issues_info(@doc['issues_info'])
    issues_info.to_json
  end

  get '/api/v1/github/commit_week_day' do
    content_type :json
    commit_week_day = commit_week_day(@doc['commit_activity_last_year'])
    commit_week_day.to_json
  end

  get '/api/v1/github/commits_month_day' do
    content_type :json
    commits = commit_heatmap(@doc['commit_activity_last_year'])
    commits.to_json
  end

end