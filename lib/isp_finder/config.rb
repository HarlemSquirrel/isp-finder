require 'yaml'

##
# Access configurations from config.yml
#
module ISPFinder
  class Config
    class << self

      def method_missing(method_name)
        config.fetch(method_name.to_s)
      end

      private

      def config
        @config ||= YAML.safe_load(File.read('config.yml'))
      end
    end
  end
end
