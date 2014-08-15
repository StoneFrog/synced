require "spec_helper"

describe Synced::Model do
  class DummyModel < ActiveRecord::Base
    def self.column_names
      %w(synced_id synced_all_at synced_data)
    end
    synced associations: %i(comments votes), remove: true
  end

  describe ".synced_id_key" do
    it "returns key used for storing remote object id" do
      expect(DummyModel.synced_id_key).to eq :synced_id
    end
  end

  describe ".synced_all_at_key" do
    it "returns key used for storing object's synchronization time" do
      expect(DummyModel.synced_all_at_key).to eq :synced_all_at
    end
  end

  describe ".synced_data_key" do
    it "returns key used for storing remote data" do
      expect(DummyModel.synced_data_key).to eq :synced_data
    end
  end

  describe ".synced_associations" do
    it "returns association(s) for which synced is enabled" do
      expect(DummyModel.synced_associations).to eq %i(comments votes)
    end
  end

  describe ".synced_remove" do
    it "returns remove setting from declared in the model" do
      expect(DummyModel.synced_remove).to be_truthy
    end
  end

  describe ".synced" do
    it "makes object synchronizeable" do
      expect(DummyModel).to respond_to(:synchronize)
    end

    it "allows to set custom synced_id_key" do
      klass = dummy_model do
        synced id_key: :remote_id
      end
      expect(klass.synced_id_key).to eq :remote_id
    end

    it "allows to set custom synced_all_at_key" do
      klass = dummy_model do
        synced synced_all_at_key: :remote_updated_at
      end
      expect(klass.synced_all_at_key).to eq :remote_updated_at
    end

    it "allows to set custom synced_data_key" do
      klass = dummy_model do
        synced data_key: :remote_data
      end
      expect(klass.synced_data_key).to eq :remote_data
    end

    context "when data_key set to nil" do
      it "doesn't create reader/writer for synced_data" do
        expect(Photo.new).not_to respond_to(:synced_data)
      end
    end

    context "when .synced_all_at_key column is present" do
      context "and only_updated is missing" do
        it "enables only_updated strategy" do
          klass = dummy_model(:synced_all_at) do
            synced
          end
          expect(klass.synced_only_updated).to be true
        end
      end

      context "and only_updated is set to false" do
        it "disables only_updated strategy" do
          klass = dummy_model(:synced_all_at) do
            synced only_updated: false
          end
          expect(klass.synced_only_updated).to be false
        end
      end
    end

    context "on unknown option" do
      it "raises unknown key exception" do
        expect {
          dummy_model { synced i_have_no_memory_of_this_place: true }
        }.to raise_error { |error|
          expect(error.message).to eq "Unknown key: :i_have_no_memory_of_this_place. " \
            + "Valid keys are: :associations, :data_key, :fields, :id_key, " \
            + ":include, :local_attributes, :mapper, :only_updated, :remove, " \
            + ":synced_all_at_key"
        }
      end
    end
  end

  describe "#synchronize" do
    it "synchronizes model" do
      expect {
        Rental.synchronize(remote: [remote_object(id: 12,
          updated_at: 2.days.ago)])
      }.to change { Rental.count }.by(1)
    end

    context "on unknown option" do
      it "raises unknown key exception" do
        expect {
          Rental.synchronize(i_have_no_memory_of_this_place: true)
        }.to raise_error { |error|
          expect(error.message).to eq "Unknown key: :i_have_no_memory_of_this_place. " \
            + "Valid keys are: :api, :fields, :include, :remote, :remove, :scope"
        }
      end
    end
  end

  def dummy_model(dummy_columns = nil, &block)
    @dummy_columns = dummy_columns
    klass = Class.new(ActiveRecord::Base) do
      def self.column_names
        @dummy_columns || %w(synced_id synced_data synced_all_at)
      end
    end
    klass.instance_eval &block
  end
end
