require "spec_helper"

describe Synced::Strategies::UpdatedSince do
  let(:account) { Account.create(name: "test") }

  describe "#perform" do
    context "with remove: true option" do
      context "deleted_ids are not present in metadata" do
        let(:remote_objects) { [remote_object(id: 12, name: "test-12")] }
        let(:account) { Account.create }
        let!(:booking) { account.bookings.create(synced_id: 10, name: "test-10") }

        before do
          allow(account.api).to receive(:paginate).with("bookings",
            { auto_paginate: true, updated_since: nil }).and_return(remote_objects)
          expect(account.api).to receive(:last_response)
            .and_return(double({ meta: {} }))
        end

        it "raises CannotDeleteDueToNoDeletedIdsError" do
          expect {
            Booking.synchronize(scope: account, remove: true, query_params: {})
          }.to raise_error(Synced::Strategies::UpdatedSince::CannotDeleteDueToNoDeletedIdsError) { |ex|
            msg = "Cannot delete Bookings. No deleted_ids were returned in API response."
            expect(ex.message).to eq msg
          }
        end
      end

      context "and credentials flow" do
        let!(:booking) { Booking.create(synced_id: 2, synced_all_at: "2010-01-01 12:12:12") }

        before do
          expect_any_instance_of(BookingSync::API::Client).to receive(:paginate).and_call_original
          expect_any_instance_of(BookingSync::API::Client).to receive(:last_response).and_call_original
        end

        it "looks for last_response within the same api instance" do
          VCR.use_cassette("deleted_ids_meta") do
            expect { Booking.synchronize(remove: true, query_params: {}) }.not_to raise_error
          end
        end

        it "deletes the booking" do
          VCR.use_cassette("deleted_ids_meta") do
            expect {
              Booking.synchronize(remove: true, query_params: {})
            }.to change { Booking.where(synced_id: 2).count }.from(1).to(0)
          end
        end
      end
    end

    describe "#perform with remote objects given" do
      context "and only_updated strategy" do
        let!(:booking) { account.bookings.create(synced_id: 42) }

        it "doesn't update synced_all_at" do
          expect{
            Booking.synchronize(remote: [remote_object(id: 42)],
              scope: account)
          }.not_to change { Booking.find_by(synced_id: 42).synced_all_at }
        end
      end
    end

    describe "with SyncedPerScopeTimestampStrategy timestamp strategy" do
      context "with account scope" do
        it "it stores, uses and resets timestamps for given scope" do
          first_sync_time = Time.zone.now.round - 1.hour

          # initial sync
          Timecop.freeze(first_sync_time) do
            expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: nil)).and_return([])
            expect {
              account.los_records.synchronize
            }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(nil).to(first_sync_time)
          end

          # second sync using the set timestamps
          second_sync_time = Time.zone.now.round
          Timecop.freeze(second_sync_time) do
            expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: first_sync_time)).and_return([])
            expect {
              account.los_records.synchronize
            }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(first_sync_time).to(second_sync_time)
          end

          # reset sync
          expect {
            account.los_records.reset_synced
          }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(second_sync_time).to(nil)

          # new fresh sync without timestamp
          expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: nil)).and_return([])
          expect {
            account.los_records.synchronize
          }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(nil)
        end
      end
    end
  end
end
