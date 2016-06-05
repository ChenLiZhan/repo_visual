Sidekiq.configure_server do |config|
  config.redis = { url: ENV['redis_uri'], network_timeout: 180}
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['redis_uri'], network_timeout: 180}
end
