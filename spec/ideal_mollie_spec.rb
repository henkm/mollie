require 'spec_helper'

describe Mollie do
  before(:each) do
    @config = Mollie::Config
    @config.reset!
    @config.test_mode = false
    @config.partner_id = 987654
    @config.report_url = "http://example.org/report"
    @config.return_url = "http://example.org/return"
  end

  context "#banks" do
    it "returns an array with banks" do
      VCR.use_cassette("banks", :match_requests_on => [:ignore_query_param_ordering]) do
        banks = Mollie.banks
        banks.is_a?(Array).should be_true
        banks.count > 0

        bank = banks.first
        bank.id.should eq "0031"
        bank.name.should eq "ABN AMRO"
      end
    end
  end

  context "#new_order" do
    it "should return a Order with the correct values" do
      VCR.use_cassette("new_order", :match_requests_on => [:ignore_query_param_ordering]) do
        order = Mollie.new_order(1000, "test", "0031")
        order.transaction_id.should eq "c9f93e5c2bd6c1e7c5bee5c5580c6f83"
        order.amount.should eq 1000
        order.currency.should eq "EUR"
        order.url.should eq "https://www.abnamro.nl/nl/ideal/identification.do?randomizedstring=8433910909&trxid=30000217841224"
        order.message.should eq "Your iDEAL-payment has successfully been setup. Your customer should visit the given URL to make the payment"
      end
    end
    it "should return a Order for profile_key with the correct values" do
      @config.profile_key = "123abc45"
      @config.update!
      VCR.use_cassette("new_order", :match_requests_on => [:ignore_query_param_ordering]) do
        order = Mollie.new_order(1000, "test", "0031")
        order.transaction_id.should eq "474ed7b2735cbe4d1f4fd4da23269263"
        order.amount.should eq 1000
        order.currency.should eq "EUR"
        order.url.should eq "https://www.abnamro.nl/nl/ideal/identification.do?randomizedstring=6616737002&trxid=30000226032385"
        order.message.should eq "Your iDEAL-payment has successfully been setup. Your customer should visit the given URL to make the payment"
      end
    end
    it "should override the return url when specified" do
      params = Mollie.new_order_params(1200, "test", "0031")
      params[:returnurl].should eq "http://example.org/return"

      params = Mollie.new_order_params(1200, "test", "0031", "http://another.example.org/return")
      params[:returnurl].should eq "http://another.example.org/return"
    end
    it "should not append the profile_key this isn't specified in the config" do
      params = Mollie.new_order_params(1200, "test", "0031")
      params.has_key?(:profile_key).should be_false
    end
    it "should append the profile_key if specified in the config" do
      @config.profile_key = 12345
      @config.update!

      params = Mollie.new_order_params(1200, "test", "0031")
      params.has_key?(:profile_key).should be_true
    end
    it "should override the report url when specified" do
      params = Mollie.new_order_params(1200, "test", "0031")
      params[:reporturl].should eq "http://example.org/report"

      params = Mollie.new_order_params(1200, "test", "0031", nil, "http://another.example.org/report")
      params[:reporturl].should eq "http://another.example.org/report"
    end
    it "should accept hash as arguments for new_order" do
      VCR.use_cassette("new_order", :match_requests_on => [:ignore_query_param_ordering]) do
        order = Mollie.new_order(amount: 1000, description: "test", bank_id: "0031")
        order.amount.should eq 1000
      end
    end
    it "should accept changing the report_url in the hash for new_order" do
      VCR.use_cassette("new_order", :match_requests_on => [:ignore_query_param_ordering]) do
        # should recieve
        params = {
          :partnerid => 987654,
          :reporturl => "http://another.example.org/report",
          :returnurl => "http://example.org/return",
          :description => "test",
          :amount => 1000,
          :bank_id => "0031"
        }
        # dummy result
        result = {}
        result["order"] = nil

        Mollie.should_receive(:request).with("fetch", params).and_return(result)

        order = Mollie.new_order(
          amount: 1000,
          description: "test",
          bank_id: "0031",
          report_url: "http://another.example.org/report")
      end
    end
    it "should accept changing the return_url in the hash for new_order" do
      VCR.use_cassette("new_order", :match_requests_on => [:ignore_query_param_ordering]) do
        # should recieve
        params = {
          :partnerid => 987654,
          :reporturl => "http://example.org/report",
          :returnurl => "http://another.example.org/return",
          :description => "test",
          :amount => 1000,
          :bank_id => "0031"
        }
        # dummy result
        result = {}
        result["order"] = nil

        Mollie.should_receive(:request).with("fetch", params).and_return(result)

        order = Mollie.new_order(
          amount: 1000,
          description: "test",
          bank_id: "0031",
          return_url: "http://another.example.org/return")
      end
    end
  end

  context "#check_order" do
    it "should return a OrderResult with the correct values" do
      VCR.use_cassette("check_order", :match_requests_on => [:ignore_query_param_ordering]) do
        order_result = Mollie.check_order("c9f93e5c2bd6c1e7c5bee5c5580c6f83")
        order_result.transaction_id.should eq "c9f93e5c2bd6c1e7c5bee5c5580c6f83"
        order_result.amount.should eq 1000
        order_result.currency.should eq "EUR"
        order_result.paid.should eq false
        order_result.message.should eq "This iDEAL-order wasn't payed for, or was already checked by you. (We give payed=true only once, for your protection)"
        order_result.status.should eq "CheckedBefore"
      end
    end

    it "should mark the OrderResult as paid and contain the customer information when called by mollie" do
      VCR.use_cassette("check_order", :match_requests_on => [:ignore_query_param_ordering]) do
        order_result = Mollie.check_order("482d599bbcc7795727650330ad65fe9b")
        order_result.transaction_id.should eq "482d599bbcc7795727650330ad65fe9b"
        order_result.amount.should eq 1000
        order_result.currency.should eq "EUR"
        order_result.paid.should eq true
        order_result.message.should eq "This iDEAL-order has successfuly been payed for, and this is the first time you check it."

        order_result.customer_name.should eq "Hr J Janssen"
        order_result.customer_account.should eq "P001234567"
        order_result.customer_city.should eq "Amsterdam"
      end
    end
  end
end
