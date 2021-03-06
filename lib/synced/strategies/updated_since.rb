require "synced/strategies/synced_all_at_timestamp_strategy"
require "synced/strategies/synced_per_scope_timestamp_strategy"

module Synced
  module Strategies
    # This strategy performs partial synchronization.
    # It fetches only changes (additions, modifications and deletions) from the API.
    class UpdatedSince < Full
      # @option options [Time|Proc] initial_sync_since: A point in time from which
      #   objects will be synchronized on first synchronization.
      def initialize(model_class, options = {})
        super
        @initial_sync_since = options[:initial_sync_since]
        timestampt_strategy_class = options[:timestamp_strategy] || Synced::Strategies::SyncedAllAtTimestampStrategy
        @timestamp_strategy = timestampt_strategy_class.new(relation_scope: relation_scope, scope: @scope, model_class: model_class)
      end

      def perform
        super.tap do |local_objects|
          instrument("update_synced_timestamp_perform.synced", model: @model_class) do
            # TODO: it can't be Time.now. this value has to be fetched from the API as well
            # https://github.com/BookingSync/synced/issues/29
            @timestamp_strategy.update(Time.now)
          end
        end
      end

      def reset_synced
        @timestamp_strategy.reset
      end

      private

      def api_request_options
        super.merge(updated_since: updated_since)
      end

      def initial_sync_since
        if @initial_sync_since.respond_to?(:call)
          @initial_sync_since.arity == 0 ? @initial_sync_since.call :
            @initial_sync_since.call(@scope)
        else
          @initial_sync_since
        end
      end

      def updated_since
        instrument("updated_since.synced") do
          [@timestamp_strategy.last_synced_at, initial_sync_since].compact.max
        end
      end

      def deleted_remote_objects_ids
        meta && meta[:deleted_ids] or raise CannotDeleteDueToNoDeletedIdsError.new(@model_class)
      end

      def meta
        remote_objects
        @meta ||= api.last_response.meta
      end

      # Remove all objects with ids from deleted_ids field in the meta key
      def remove_relation
        relation_scope.where(@id_key => deleted_remote_objects_ids)
      end

      class CannotDeleteDueToNoDeletedIdsError < StandardError
        def initialize(model_class)
          @model_class = model_class
        end

        def message
          "Cannot delete #{pluralized_model_class}. No deleted_ids were returned in API response."
        end

        private

        def pluralized_model_class
          @model_class.to_s.pluralize
        end
      end
    end
  end
end
