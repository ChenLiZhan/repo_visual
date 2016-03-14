# Repo Miner Service

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://repo-crawler.herokuapp.com/)

### Description
It's a web service responsible for collecting gems and presenting the information via dashboard.
### Run it locally
1. set the environment variables
    * github_token
    * github_account
    * github_password
    * user_agent
    * stackoverflow_token
    * mongodb_uri
    * redis_uri
    * host
2. run ```bundle install```
3. run the other required service(MongoDB, Redis, Sidekiq)
    * Mongodb: ```sudo mongod```
    * Redis: ```redis-server```
    * sidekiq: ```sidekiq -r ./app.rb```
4. run ```rackup -p <port>``` to start the service