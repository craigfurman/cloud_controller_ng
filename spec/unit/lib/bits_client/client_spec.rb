require 'spec_helper'
require 'bits_client/client'

require 'securerandom'

describe BitsClient do
  let(:endpoint) { 'http://bits-service.com/' }

  let(:guid) { SecureRandom.uuid }

  subject { BitsClient.new(endpoint: endpoint) }

  describe 'forwards vcap-request-id' do
    let(:file_path) { Tempfile.new('buildpack').path }
    let(:file_name) { 'my-buildpack.zip' }

    it 'includes the header with a POST request' do
      expect(VCAP::Request).to receive(:current_id).and_return('0815')

      request = stub_request(:post, 'http://bits-service.com/buildpacks').
                with(body: /.*buildpack".*/, headers: { 'X-Vcap-Request_Id' => '0815' }).
                to_return(status: 201)

      subject.upload_buildpack(file_path, file_name)
      expect(request).to have_been_requested
    end
  end

  context 'Buildpack Cache' do
    describe '#upload_buildpack_cache' do
      let(:file_path) { Tempfile.new('buildpack').path }
      let(:key) { '1234/567' }

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:put, 'http://bits-service.com/buildpack_cache/1234/567').
                  to_return(status: 201)

        subject.upload_buildpack_cache(key, file_path)
        expect(request).to have_been_requested
      end
    end

    describe '#delete_buildpack_cache' do
      let(:key) { '1234/567' }
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:delete, 'http://bits-service.com/buildpack_cache/1234/567').
                  to_return(status: 204)
        subject.delete_buildpack_cache(key)
        expect(request).to have_been_requested
      end
    end

    describe '#delete_all_buildpack_caches' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:delete, 'http://bits-service.com/buildpack_cache/').
                  to_return(status: 204)
        subject.delete_all_buildpack_caches
        expect(request).to have_been_requested
      end
    end

    describe '#download_url' do
      it 'returns the bits-service download endpoint for the key' do
        url = subject.download_url(:buildpack_cache, '1234/567')
        expect(url).to eq('http://bits-service.com/buildpack_cache/1234/567')
      end
    end
  end

  context 'Buildpacks' do
    describe '#upload_buildpack' do
      let(:file_path) { Tempfile.new('buildpack').path }
      let(:file_name) { 'my-buildpack.zip' }

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:post, 'http://bits-service.com/buildpacks').
                  with(body: /.*buildpack".*/).
                  to_return(status: 201)

        subject.upload_buildpack(file_path, file_name)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/buildpacks').
          to_return(status: 201)

        response = subject.upload_buildpack(file_path, file_name)
        expect(response).to be_a(Net::HTTPCreated)
      end

      it 'raises an error when the response is not 201' do
        stub_request(:post, 'http://bits-service.com/buildpacks').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.upload_buildpack(file_path, file_name)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end

      context 'when invalid buildpack is given' do
        it 'raises the correct exception' do
          expect {
            subject.upload_buildpack('/not-here', file_name)
          }.to raise_error(BitsClient::Errors::FileDoesNotExist)
        end
      end
    end

    describe '#download_url' do
      it 'returns the bits-service download endpoint for the guid' do
        url = subject.download_url(:buildpacks, '1234')
        expect(url).to eq('http://bits-service.com/buildpacks/1234')
      end
    end

    describe '#delete_buildpack' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:delete, "http://bits-service.com/buildpacks/#{guid}").
                  to_return(status: 204)

        subject.delete_buildpack(guid)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:delete, "http://bits-service.com/buildpacks/#{guid}").
          to_return(status: 204)

        response = subject.delete_buildpack(guid)
        expect(response).to be_a(Net::HTTPNoContent)
      end

      it 'raises an error when the response is not 204' do
        stub_request(:delete, "http://bits-service.com/buildpacks/#{guid}").
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.delete_buildpack(guid)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end
  end

  context 'Droplets' do
    describe '#upload_droplet' do
      let(:file_path) { Tempfile.new('droplet').path }

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:post, 'http://bits-service.com/droplets').
                  with(body: /.*droplet".*/).
                  to_return(status: 201)

        subject.upload_droplet(file_path)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/droplets').
          to_return(status: 201)

        response = subject.upload_droplet(file_path)
        expect(response).to be_a(Net::HTTPCreated)
      end

      it 'raises an error when the response is not 201' do
        stub_request(:post, 'http://bits-service.com/droplets').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.upload_droplet(file_path)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end

      context 'when invalid droplet is given' do
        it 'raises the correct exception' do
          expect {
            subject.upload_droplet('/not-here')
          }.to raise_error(BitsClient::Errors::FileDoesNotExist)
        end
      end
    end

    describe '#delete_droplet' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:delete, "http://bits-service.com/droplets/#{guid}").
                  to_return(status: 204)

        subject.delete_droplet(guid)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:delete, "http://bits-service.com/droplets/#{guid}").
          to_return(status: 204)

        response = subject.delete_droplet(guid)
        expect(response).to be_a(Net::HTTPNoContent)
      end

      it 'raises an error when the response is not 204' do
        stub_request(:delete, "http://bits-service.com/droplets/#{guid}").
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.delete_droplet(guid)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#download_url' do
      it 'returns the bits-service download endpoint for the guid' do
        url = subject.download_url(:droplets, '1234')
        expect(url).to eq('http://bits-service.com/droplets/1234')
      end
    end
  end

  context 'Packages' do
    describe '#upload_package' do
      let(:file_path) { Tempfile.new('package').path }

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:post, 'http://bits-service.com/packages').
                  with(body: /.*package".*/).
                  to_return(status: 201)

        subject.upload_package(file_path)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/packages').
          to_return(status: 201)

        response = subject.upload_package(file_path)
        expect(response).to be_a(Net::HTTPCreated)
      end

      it 'raises an error when the response is not 201' do
        stub_request(:post, 'http://bits-service.com/packages').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.upload_package(file_path)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end

      context 'when invalid package is given' do
        it 'raises the correct exception' do
          expect {
            subject.upload_package('/not-here')
          }.to raise_error(BitsClient::Errors::FileDoesNotExist)
        end
      end
    end

    describe '#delete_package' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:delete, "http://bits-service.com/packages/#{guid}").
                  to_return(status: 204)

        subject.delete_package(guid)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:delete, "http://bits-service.com/packages/#{guid}").
          to_return(status: 204)

        response = subject.delete_package(guid)
        expect(response).to be_a(Net::HTTPNoContent)
      end

      it 'raises an error when the response is not 204' do
        stub_request(:delete, "http://bits-service.com/packages/#{guid}").
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.delete_package(guid)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#download_package' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:get, "http://bits-service.com/packages/#{guid}").
                  to_return(status: 200)

        subject.download_package(guid)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:get, "http://bits-service.com/packages/#{guid}").
          to_return(status: 200)

        response = subject.download_package(guid)
        expect(response).to be_a(Net::HTTPOK)
      end

      it 'raises an error when the response is not 20X' do
        stub_request(:get, "http://bits-service.com/packages/#{guid}").
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.download_package(guid)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#duplicate_package' do
      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:post, 'http://bits-service.com/packages').
                  with(body: JSON.generate('source_guid' => guid)).
                  to_return(status: 201)

        subject.duplicate_package(guid)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/packages').to_return(status: 201)

        response = subject.duplicate_package(guid)
        expect(response).to be_a(Net::HTTPCreated)
      end

      it 'raises an error when the response is not 201' do
        stub_request(:post, 'http://bits-service.com/packages').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.duplicate_package(guid)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#download_url' do
      it 'returns the bits-service download endpoint for the guid' do
        url = subject.download_url(:packages, '1234')
        expect(url).to eq('http://bits-service.com/packages/1234')
      end
    end
  end

  context 'AppStash' do
    describe '#matches' do
      let(:resources) do
        [{ 'sha1' => 'abcde' }, { 'sha1' => '12345' }]
      end

      it 'makes the correct request to the bits endpoint' do
        request = stub_request(:post, 'http://bits-service.com/app_stash/matches').
                  with(body: resources.to_json).
                  to_return(status: 200, body: [].to_json)

        subject.matches(resources.to_json)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/app_stash/matches').
          with(body: resources.to_json).
          to_return(status: 200, body: [].to_json)

        response = subject.matches(resources.to_json)
        expect(response).to be_a(Net::HTTPOK)
      end

      it 'raises an error when the response is not 200' do
        stub_request(:post, 'http://bits-service.com/app_stash/matches').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.matches(resources.to_json)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#upload_entries' do
      let(:zip) { Tempfile.new('entry.zip') }

      it 'posts a zip file with new bits' do
        request = stub_request(:post, 'http://bits-service.com/app_stash/entries').
                  with(body: /.*application".*/).
                  to_return(status: 201)

        subject.upload_entries(zip)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/app_stash/entries').
          with(body: /.*application".*/).
          to_return(status: 201)

        response = subject.upload_entries(zip)
        expect(response).to be_a(Net::HTTPCreated)
      end

      it 'raises an error when the response is not 201' do
        stub_request(:post, 'http://bits-service.com/app_stash/entries').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.upload_entries(zip)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end

    describe '#bundles' do
      let(:order) {
        [{ 'fn' => 'app.rb', 'sha1' => '12345' }]
      }

      let(:content_bits) { 'tons of bits as ordered' }

      it 'makes the correct request to the bits service' do
        request = stub_request(:post, 'http://bits-service.com/app_stash/bundles').
                  with(body: order.to_json).
                  to_return(status: 200, body: content_bits)

        subject.bundles(order.to_json)
        expect(request).to have_been_requested
      end

      it 'returns the request response' do
        stub_request(:post, 'http://bits-service.com/app_stash/bundles').
          with(body: order.to_json).
          to_return(status: 200, body: content_bits)

        response = subject.bundles(order.to_json)
        expect(response).to be_a(Net::HTTPOK)
      end

      it 'raises an error when the response is not 200' do
        stub_request(:post, 'http://bits-service.com/app_stash/bundles').
          to_return(status: 400, body: '{"description":"bits-failure"}')

        expect {
          subject.bundles(order.to_json)
        }.to raise_error(BitsClient::Errors::Error, 'bits-failure')
      end
    end
  end
end
