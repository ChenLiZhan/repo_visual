require 'sinatra/base'
require 'chartkick'
require 'mongo'


class VizApp < Sinatra::Base
  client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')
  
  helpers do
    def version_downloads(data)
      version_downloads_hash = {}
      data.each do |row|
        version_downloads_hash[row['number']] = row['downloads']
      end

      version_downloads_hash
    end

    def commit_week_day(data)
      commit_week_day = {
        'Sunday'    => 0,
        'Monday'    => 0,
        'Tuesday'   => 0,
        'Wednesday' => 0,
        'Thursday'  => 0,
        'Friday'    => 0,
        'Saturday'  => 0
      }
      data.each do |row|
        commit_week_day['Sunday'] += row['days'][0]
        commit_week_day['Monday'] += row['days'][1]
        commit_week_day['Tuesday'] += row['days'][2]
        commit_week_day['Wednesday'] += row['days'][3]
        commit_week_day['Thursday'] += row['days'][4]
        commit_week_day['Friday'] += row['days'][5]
        commit_week_day['Saturday'] += row['days'][6]
      end

      commit_week_day
    end

    def closed_issues(data)
      data.map! do |row|
        [row['number'], row['duration']]
      end

      data
    end
  end
  
  get '/' do
    documents = []
    client[:gems].find.each do |document|
      documents << document
    end      

    @doc = documents.last

    @version_downloads = version_downloads(@doc['version_downloads'])
    @commit_week_day = commit_week_day(@doc['commit_activity_last_year'])
    @closed_issues = closed_issues(@doc['closed_issues'])
    erb :index
  end
end