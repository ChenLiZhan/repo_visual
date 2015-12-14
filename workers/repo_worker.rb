require 'sidekiq'
require 'redis'

class RepoWorker
  include Sidekiq::Worker

  def perform
    sleep(3)
  end
end