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
            Booking.synchronize(scope: account, remove: true)
          }.to raise_error(Synced::Strategies::UpdatedSince::CannotDeleteDueToNoDeletedIdsError) { |ex|
            msg = "Cannot delete Bookings. No deleted_ids were returned in API response."
            expect(ex.message).to eq msg
          }
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
  end
end