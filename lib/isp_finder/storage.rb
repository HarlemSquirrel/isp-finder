require 'pstore'

module ISPFinder
  class Storage
    class Error < StandardError; end

    FILE_NAME = 'isp_finder.pstore'

    class << self
      def delete(key)
        new.delete(key)
      end

      def fetch(key, proc)
        new.fetch(key, proc)
      end

      def read(key)
        new.read(key)
      end

      def write(key, value)
        new.write(key, value)
      end
    end

    def delete(key)
      store.transaction { store.delete(key) }
    end

    def fetch(key, proc)
      return proc.call if testing?

      value = read(key)
      return value if value

      # Load the resources outside the store transaction so we don't lock while performing
      # network requests
      value = proc.call
      store.transaction { store[key] = value }
    end

    def read(key)
      store.transaction(true) { return store[key] }
    end

    def write(key, value)
      store.transaction { store[key] = value }
    end

    private

    def store
      @store ||= PStore.new(FILE_NAME, true)
    end

    def testing?
      defined?(ISP_FINDER_ENV) && ISP_FINDER_ENV == 'test'
    end
  end
end
