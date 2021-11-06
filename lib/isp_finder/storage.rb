require 'pstore'

module ISPFinder
  class Storage
    class Error < StandardError; end

    class << self
      def fetch(key, proc)
        return proc.call if testing?

        value = store.transaction { store[key] }
        return value if value

        # Load the resources outside the store transaction so we don't lock while performing
        # network requests
        value = proc.call
        store.transaction { store[key] ||= value }
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
