Sinatra::Application.database.extension(:connection_validator)
Sinatra::Application.database.pool.connection_validation_timeout = -1

Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers

require 'app/models/user'
require 'app/models/site'
require 'app/models/submission'
require 'app/models/area'
