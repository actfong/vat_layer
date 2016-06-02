require "spec_helper"

describe Apilayer::Vat do
  before do
    Apilayer::Vat.configure do |configs|
      configs.access_key = "vat_layer_key123"
    end
  end

  describe :connection do
    context "vat_layer access_key has been set" do
      it "returns a connection with correct attributes" do
        conn = Apilayer::Vat.connection

        expect(conn).to be_a Faraday::Connection
        expect(conn.url_prefix.host).to match "apilayer.net"
        expect(conn.params["access_key"]).to eq "vat_layer_key123"
      end
    end

    context "non-secure connection" do
      it "returns a connection to http protocol" do
        conn = Apilayer::Vat.connection
        expect(conn.url_prefix).to be_a URI::HTTP
      end
    end

    context "secure connection" do
      before do
        Apilayer::Vat.configure do |configs|
          configs.https = true
        end
      end
      after do
        Apilayer::Vat.configure do |configs|
          configs.https = false
        end
      end

      it "returns a connection to https protocol" do
        conn = Apilayer::Vat.connection
        expect(conn.url_prefix).to be_a URI::HTTPS
      end
    end
  end

  describe :validate do
    it "returns a Hash with VAT data" do
      VCR.use_cassette("vat/validation") do
        api_resp = Apilayer::Vat.validate("LU26375245")
        expect(api_resp["query"]).to eq "LU26375245"
        expect(api_resp["company_name"]).to eq "AMAZON EUROPE CORE S.A R.L."
      end
    end

    it "passes vat_number to get_and_parse" do
      VCR.use_cassette("vat/validation") do
        expect(Apilayer::Vat).to receive(:get_and_parse).with(
          "validate", {:vat_number => "LU26375245"}
        )
        Apilayer::Vat.validate("LU26375245")
      end      
    end
  end

  describe :rate do
    context "country_code provided as criteria" do
      it "returns a Hash with VAT rate for the specified country" do
        VCR.use_cassette("vat/rate_by_country_code") do
          api_resp = Apilayer::Vat.rate(:country_code, "NL")
          expect(api_resp['standard_rate']).to be_a Numeric
          expect(api_resp['reduced_rates']).to be_a Hash
        end
      end

      it "passes country_code to get_and_parse" do
        VCR.use_cassette("vat/validation") do
          expect(Apilayer::Vat).to receive(:get_and_parse).with(
            "rate", {:country_code => "NL"}
          )
          Apilayer::Vat.rate(:country_code, "NL")
        end      
      end      
    end

    context "ip_address provided as criteria" do
      it "returns a Hash with VAT rate for the specified country" do
        VCR.use_cassette("vat/rate_by_ip_address") do
          api_resp = Apilayer::Vat.rate(:ip_address, "176.249.153.36")
          expect(api_resp['standard_rate']).to be_a Numeric
          expect(api_resp['reduced_rates']).to be_a Hash
        end
      end

      it "passes ip_address to get_and_parse" do
        VCR.use_cassette("vat/rate_by_ip_address") do
          expect(Apilayer::Vat).to receive(:get_and_parse).with(
            "rate", {:ip_address => "176.249.153.36"}
          )
          Apilayer::Vat.rate(:ip_address, "176.249.153.36")
        end
      end
    end    
  end

  describe :rate_list do
    it "returns VAT rates for all 28 EU countries" do
      VCR.use_cassette("vat/rate_list") do
        api_resp = Apilayer::Vat.rate_list
        expect(api_resp["rates"].count).to eq 28
      end
    end

    it "invokes get_and_parse" do
      VCR.use_cassette("vat/rate_list") do
        expect(Apilayer::Vat).to receive(:get_and_parse).with("rate_list")
        Apilayer::Vat.rate_list
      end
    end  
  end

  describe :price do
    context "invalid criteria provided" do
      it 'raises an error' do
        expect{Apilayer::Vat.price(100, :foobar, "Some Value")}.to raise_error(
          Apilayer::Error,
          "You must provide either :country_code or :ip_address"
        )
      end
    end

    context "calculation based on country_code" do
      it 'returns price incl/excl VAT and country_code' do
        VCR.use_cassette("vat/price_by_country_code") do
          api_resp = Apilayer::Vat.price(100, :country_code, "NL")
          expect(api_resp["country_name"]).to eq "Netherlands"
          expect(api_resp["price_excl_vat"]).to eq 100
          expect(api_resp["price_incl_vat"]).to eq 121
          expect(api_resp["vat_rate"]).to eq 21
        end
      end

      it "invokes get_and_parse with country_code" do
        VCR.use_cassette("vat/price_by_country_code") do
          expect(Apilayer::Vat).to receive(:get_and_parse).with(
            "price",
            hash_including(:amount => 100, :country_code => "NL")
          )
          Apilayer::Vat.price(100, :country_code, "NL")
        end
      end
    end

    context "calculation based on ip_address" do
      it "returns price incl/excl VAT and ip_address" do
        VCR.use_cassette("vat/price_by_ip_address") do
          api_resp = Apilayer::Vat.price(100, :ip_address, "176.249.153.36")
          expect(api_resp["country_name"]).to eq "United Kingdom"
          expect(api_resp["price_excl_vat"]).to eq 100
          expect(api_resp["price_incl_vat"]).to eq 120
          expect(api_resp["vat_rate"]).to eq 20   
        end
      end

      it "invokes get_and_parse with ip_address" do
        VCR.use_cassette("vat/price_by_ip_address") do
          expect(Apilayer::Vat).to receive(:get_and_parse).with(
            "price",
            hash_including(:amount => 100, :ip_address => "176.249.153.36")
          )
          Apilayer::Vat.price(100, :ip_address, "176.249.153.36")
        end
      end

    end
  end

end

