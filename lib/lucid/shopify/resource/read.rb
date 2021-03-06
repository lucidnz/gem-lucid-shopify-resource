# frozen_string_literal: true

require 'lucid/shopify/resource/base'

module Lucid
  module Shopify
    module Resource
      # @example
      #   class OrderRepository
      #     include Lucid::Shopify::Resource::Read
      #
      #     resource :orders
      #
      #     default_params fields: %w[id tags]
      #
      #     # ...
      #   end
      module Read
        module ClassMethods
          # Set the default query params. Note that 'fields' may be passed as an
          # array of strings.
          #
          # @param params [Hash]
          #
          # @example
          #   default_params fields: %w(id tags)
          def default_params(params)
            define_method(:default_params) { params }
          end
        end

        include Enumerable

        # @param base [Class, Module]
        def self.included(base)
          base.extend(ClassMethods)
          base.include(Base)
        end

        # @abstract Use {ClassMethods#default_params} to implement (optional)
        #
        # @return [Hash]
        def default_params
          {}
        end

        # Defaults set by Shopify when not specified.
        #
        # @return [Hash]
        def default_shopify_params
          {
            limit: 50,
          }
        end

        # @param credentials [Credentials]
        # @param id [Integer]
        # @param params [Hash]
        #
        # @return [Hash]
        def find(credentials, id, params = {})
          params = finalise_params(params)

          logger.info("Fetching #{resource_singular} id=#{id}")

          client.get(credentials, "#{resource}/#{id}", params)[resource_singular]
        end

        # Iterate over results. If set, the 'fields' option must include 'id'.
        #
        # Throttling is always enabled.
        #
        # @param credentials [Credentials]
        # @param params [Hash]
        #
        # @yield [Hash]
        #
        # @return [Enumerator]
        #
        # @raise [ArgumentError] if 'fields' does not include 'id'
        def each(credentials, params = {})
          return to_enum(__method__, credentials, params) unless block_given?

          assert_fields_id!(params = finalise_params(params))

          since_id = params.delete('since_id') || 1

          loop do
            logger.info("Fetching #{resource} since_id=#{since_id}")

            results = client.get(credentials, resource, params.merge(since_id: since_id))[resource]
            results.each do |result|
              yield result
            end

            break if results.empty?

            since_id = results.last['id']
          end
        end

        # @param params [Hash] the finalised params (see {#finalise_params})
        private def assert_fields_id!(params)
          return unless params['fields']
          return unless params['fields'] !~ /\bid\b/

          raise ArgumentError, 'attempt to paginate without id field'
        end

        # @param credentials [Credentials]
        # @param params [Hash]
        #
        # @return [Integer]
        def count(credentials, params = {})
          params = finalise_params(params)

          logger.info("Fetching #{resource} count")

          client.get(credentials, "#{resource}/count", params)['count']
        end

        # Merge with default params and format for query string.
        #
        # @param params [Hash]
        #
        # @return [Hash]
        private def finalise_params(params)
          params = default_shopify_params.merge(default_params).merge(params)

          params.each_with_object({}) do |(k, v), h|
            k = k.to_s
            k == 'fields' && v.is_a?(Array) ? v.join(',') : v
            h[k] = v
          end
        end
      end
    end
  end
end
