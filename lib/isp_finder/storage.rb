require 'pstore'

module ISPFinder
  class Storage
    class Error < StandardError; end

    class << self
      def fetch(key, proc)
        return proc.call if testing?

        store.transaction do
          store[key] ||= proc.call
        end
      end

      private

      def store
        @store ||= PStore.new('isp_finder.pstore', true)
      end

      def testing?
        defined?(ISP_FINDER_ENV) && ISP_FINDER_ENV == 'test'
      end
    end
  end
end
