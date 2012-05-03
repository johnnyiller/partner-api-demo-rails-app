require 'ostruct'
require 'yaml'

priv_config = "/Users/jeffdurand/Desktop/appconfig.yml"
loadfile = File.exists?(priv_config) ? priv_config : "#{Rails.root}/config/appconfig.yml"

config = OpenStruct.new(YAML.load_file(loadfile))
::AppConfig = OpenStruct.new(config.send(Rails.env))
