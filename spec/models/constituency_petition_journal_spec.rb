require 'rails_helper'

RSpec.describe ConstituencyPetitionJournal, type: :model do
  it "has a valid factory" do
    expect(FactoryGirl.build(:constituency_petition_journal)).to be_valid
  end

  describe "defaults" do
    subject { described_class.new }
    it "has 0 for initial signature_count" do
      expect(subject.signature_count).to eq 0
    end
  end

  describe "indexes" do
    it { is_expected.to have_db_index([:petition_id, :constituency_id]).unique }
  end

  describe "validations" do
    subject { FactoryGirl.build(:constituency_petition_journal) }

    it { is_expected.to validate_presence_of(:constituency_id) }
    it { is_expected.to validate_length_of(:constituency_id).is_at_most(255) }
    it { is_expected.to validate_presence_of(:petition) }
    it { is_expected.to validate_uniqueness_of(:constituency_id).scoped_to(:petition_id) }
    it { is_expected.to validate_presence_of(:signature_count) }
  end

  describe ".for" do
    let(:petition) { FactoryGirl.create(:petition) }
    let(:constituency_id) { FactoryGirl.generate(:constituency_id) }

    context "when there is a journal for the requested petition and constituency" do
      let!(:existing_record) { FactoryGirl.create(:constituency_petition_journal, petition: petition, constituency_id: constituency_id, signature_count: 30) }

      it "doesn't create a new record" do
        expect {
          described_class.for(petition, constituency_id)
        }.not_to change(described_class, :count)
      end

      it "fetches the instance from the DB" do
        fetched = described_class.for(petition, constituency_id)
        expect(fetched).to eq existing_record
      end
    end

    context "when there is no journal for the requested petition and constituency" do
      it "creates a new instance in the DB" do
        expect {
          described_class.for(petition, constituency_id)
        }.to change(described_class, :count).by(1)
      end

      it "returns the newly created instance" do
        fetched = described_class.for(petition, constituency_id)
        expect(fetched).to be_a described_class
        expect(fetched).to be_persisted
      end

      it "sets the petition of the new instance to the supplied petition" do
        fetched = described_class.for(petition, constituency_id)
        expect(fetched.petition).to eq petition
      end

      it "sets the constituency_id of the new instance to the supplied petition" do
        fetched = described_class.for(petition, constituency_id)
        expect(fetched.constituency_id).to eq constituency_id
      end

      it "has 0 for a signature count" do
        fetched = described_class.for(petition, constituency_id)
        expect(fetched.signature_count).to eq 0
      end
    end
  end

  describe "#record_new_signature" do
    let(:petition) { FactoryGirl.create(:petition) }
    let(:constituency_id) { FactoryGirl.generate(:constituency_id) }

    subject { described_class.for(petition, constituency_id) }

    it "increments signature_count by 1" do
      expect {
        subject.record_new_signature
      }.to change(subject, :signature_count).by(1)
    end

    it "persists the change" do
      old_signature_count = subject.signature_count
      subject.record_new_signature
      subject.reload
      expect(subject.signature_count).not_to eq old_signature_count
    end
  end

  describe ".record_new_signature_for" do
    let(:petition) { FactoryGirl.create(:open_petition) }
    let(:constituency_id) { FactoryGirl.generate(:constituency_id) }
    let(:signature) { FactoryGirl.build(:validated_signature, petition: petition, constituency_id: constituency_id) }

    it "does nothing if the supplied signature is nil" do
      expect {
        described_class.record_new_signature_for(nil)
      }.not_to change(described_class, :count)
    end

    it "does nothing if the supplied signature has no petition" do
      signature.petition = nil
      expect {
        described_class.record_new_signature_for(signature)
      }.not_to change(described_class, :count)
    end

    it "does nothing if the supplied signature has no constituency_id" do
      signature.constituency_id = nil
      expect {
        described_class.record_new_signature_for(signature)
      }.not_to change(described_class, :count)
    end

    it "does nothing if the supplied signature is not validated?" do
      signature.state = Signature::PENDING_STATE
      expect {
        described_class.record_new_signature_for(signature)
      }.not_to change(described_class, :count)
    end

    it "creates a new instance and sets the count to 1 if nothing exists already" do
      expect {
        described_class.record_new_signature_for(signature)
      }.to change(described_class, :count).by(1)
      expect(described_class.for(petition, constituency_id).signature_count).to eq 1
    end

    it "increments the signature_count of the existing instance by 1" do
      existing = described_class.for(signature.petition, signature.constituency_id)
      existing.update_column(:signature_count, 20)

      described_class.record_new_signature_for(signature)

      existing.reload
      expect(existing.signature_count).to eq 21
    end
  end
end