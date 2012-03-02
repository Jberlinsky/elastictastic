require 'faraday'

module Elastictastic
  class Client
    attr_reader :connection

    def initialize(config)
      builder = Faraday::Builder.new do |builder|
        builder.use Middleware::AddGlobalTimeout
        builder.use Middleware::RaiseServerErrors
        builder.use Middleware::JsonEncodeBody
        builder.use Middleware::JsonDecodeResponse
        if config.logger
          builder.use Middleware::LogRequests, config.logger
        end
        builder.use Middleware::RaiseOnStatusZero
        if Class === config.adapter then builder.use(config.adapter) 
        else builder.adapter config.adapter
        end
      end
      if config.hosts.length == 1
        @connection =
          Faraday.new(:url => config.hosts.first, :builder => builder)
      else
        @connection = Rotor.new(
          config.hosts,
          :builder => builder,
          :backoff_threshold => config.backoff_threshold,
          :backoff_start => config.backoff_start,
          :backoff_max => config.backoff_max
        )
      end
    end

    def create(index, type, id, doc, params = {})
      if id
        @connection.put(
          path_with_query("/#{index}/#{type}/#{id}/_create", params), doc)
      else
        @connection.post(path_with_query("/#{index}/#{type}", params), doc)
      end.body
    end

    def update(index, type, id, doc, params = {})
      @connection.put(path_with_query("/#{index}/#{type}/#{id}", params), doc).body
    end

    def bulk(commands, params = {})
      @connection.post(path_with_query('/_bulk', params), commands).body
    end

    def get(index, type, id, params = {})
      @connection.get(path_with_query("/#{index}/#{type}/#{id}", params)).body
    end

    def mget(docspec, index = nil, type = nil)
      path =
        if index.present?
          if type.present?
            "/#{index}/#{type}/_mget"
          else index.present?
            "#{index}/_mget"
          end
        else
          "/_mget"
        end
      @connection.post(path, 'docs' => docspec).body
    end

    def search(index, type, search, options = {})
      path = "/#{index}/#{type}/_search"
      @connection.post(
        "#{path}?#{options.to_query}",
        search
      ).body
    end

    def msearch(search_bodies)
      @connection.post('/_msearch', search_bodies).body
    end

    def scroll(id, options = {})
      @connection.post(
        "/_search/scroll?#{options.to_query}",
        id
      ).body
    end

    def put_mapping(index, type, mapping)
      @connection.put("/#{index}/#{type}/_mapping", mapping).body
    end

    def delete(index = nil, type = nil, id = nil, params = {})
      path =
        if id then "/#{index}/#{type}/#{id}"
        elsif type then "/#{index}/#{type}"
        elsif index then "/#{index}"
        else "/"
        end
      @connection.delete(path_with_query(path, params)).body
    end

    private

    def path_with_query(path, query)
      if query.present?
        "#{path}?#{query.to_query}"
      else
        path
      end
    end
  end
end
