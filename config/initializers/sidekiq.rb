Sidekiq.configure_server do |config|
  config.redis = { url: ENV['redis_uri'], network_timeout: 5}
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['redis_uri'], network_timeout: 5}
end
