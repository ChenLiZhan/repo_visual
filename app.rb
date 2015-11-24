require 'sinatra/base'
require 'chartkick'
require 'mongo'
require 'httparty'
require 'date'

class VizApp < Sinatra::Base
  client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'gems_info')
  
  before do
    documents = []
    client[:gems].find.each do |document|
      documents << document
    end      

    @doc = documents.last
  end

  helpers do
    def version_downloads(data)
      version_downloads_hash = {}
      data.each do |row|
        version_downloads_hash[row['number']] = row['downloads']
      end

      version_downloads_hash
    end

    def version_downloads_stack(data)
      general_data = []
      data.each do |row|
        if general_data[row['number'].split('.').first.to_i].nil?
          general_data[row['number'].split('.').first.to_i] = 0
        end
        general_data[row['number'].split('.').first.to_i] += row['downloads']
      end

      final_general = general_data.each_with_index.map do |row, index|
        {
          'name'    => "Version #{index}.*",
          'y'       => row,
          'drilldown' => "Version #{index}.*"
        }
      end

      specific_data = []
      data.each do |row|
        if specific_data[row['number'].split('.').first.to_i].nil?
          specific_data[row['number'].split('.').first.to_i] = []
        end
        specific_data[row['number'].split('.').first.to_i] << [row['number'], row['downloads']]
      end

      final_specific = specific_data.each_with_index.map do |row, index|
        {
          'name'  => "Version #{index}.*",
          'id'    => "Version #{index}.*",
          'data'  => row
        }
      end

      [final_general, final_specific]
    end

    def version_downloads_nest(data)
      major_data = []
      data.each do |row|
        if major_data[row['number'].split('.').first.to_i].nil?
          major_data[row['number'].split('.').first.to_i] = 0
        end
        major_data[row['number'].split('.').first.to_i] += row['downloads']
      end

      major = major_data.each_with_index.map do |row, index|
        {
          'name'    => "Version #{index}.*",
          'y'       => row,
          'drilldown' => "Version #{index}.*"
        }
      end

      minor_data = []
      data.each do |row|
        if minor_data[row['number'].split('.').first.to_i].nil?
          minor_data[row['number'].split('.').first.to_i] = []
        end
        minor_data[row['number'].split('.').first.to_i] << [row['number'], row['downloads']]
      end

      minor_hash = Hash.new(0)
      minor_data.each do |row|
        row.each do |version|
          maj, min, pat = version[0].split('.')
          if minor_hash["Version #{maj}.#{min}.*"].nil?
            minor_hash["Version #{maj}.#{min}.*"] = 0
          end
          minor_hash["Version #{maj}.#{min}.*"] += version[1]
        end
      end

      m_data = {}
      minor_hash.each do |index, value|
        major_ver = index.match(/[0-9]/)
        minor_ver = index.match(/[0-9].[0-9]/)
        
        if m_data[major_ver.to_s].nil?
          m_data[major_ver.to_s] = []
        end

        m_data[major_ver.to_s] << {
          'name'    => index,
          'y'       => value,
          'drilldown' => "Version #{minor_ver}.*"
        }
      end

      minor = m_data.map do |index, value|
        major_ver = value[0]['name'].match(/[0-9]/)

        {
          'id'      => "Version #{major_ver}.*",
          'name'    => "Version #{major_ver}.*",
          'data'    => value
        }
      end

      path_hash = {}
      data.each do |row|
        maj, min, pat = row['number'].split('.')
        if path_hash["Version #{maj}.#{min}.*"].nil?
          path_hash["Version #{maj}.#{min}.*"] = []
        end
        path_hash["Version #{maj}.#{min}.*"] << [row['number'], row['downloads']]
      end

      path = path_hash.map do |row|
        {
          'id'    => row[0],
          'data'  => row[1]
        }
      end

      nest_drilldown = [minor, path].flatten

      [major, nest_drilldown]
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

    def version_downloads_days(data)
      version_downloads_days = []
      data.each do |row|
        process = row['downloads_date'].map do |data|
          date = data[0].split('-')
          [Date.new(date[0].to_i, date[1].to_i, date[2].to_i).to_time.to_i * 1000, data[1]]
        end
        version_downloads_days << {'name' => row['number'], 'data' => process}
      end

      version_downloads_days
    end

    # def commit_heatmap(data)
    #   # cwday
    #   # month

    #   commits_transform = {
    #     'data'  => [],
    #     'max'   => 0
    #   }
    #   commits_transform['data'] << ['Date', 'Day', 'Commits']
    #   data.each do |row|
    #     stamp = row['week']
    #     counter = 0
    #     row['days'].each_with_index do |value, index|
    #       commits_transform['max'] = value if value > commits_transform['max']

    #       date = Date.strptime((row['week'] + 86400 * counter).to_s,'%s').to_s
    #       commits_transform['data'] << [date, index, value]
    #       counter += 1
    #     end
    #   end

    #   commits_transform['data'] = commits_transform['data'].map do |row|
    #     row.join(',')
    #   end.join(' ')

    #   commits_transform
    # end

    def issues_info(data)
      data.map! do |row|
        [row['number'], row['duration']]
      end

      data
    end
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

  # get '/api/v1/github/commits_month_day' do
  #   content_type :json
  #   commits = commit_heatmap(@doc['commit_activity_last_year'])
  #   commits.to_json
  # end

end