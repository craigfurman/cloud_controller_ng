require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe ExternalPacker do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:app) { App.make }
      let(:app_guid) { app.guid }
      let(:package_blobstore) { double(:package_blobstore) }
      let(:receipt) { [{ 'sha1' => '12345', 'fn' => 'app.rb' }] }
      let(:fingerprints) { [{ 'sha1' => 'abcde', 'fn' => 'lib.rb' }] }
      let(:package_file) { Tempfile.new('package') }
      let(:package_guid) { 'package-guid' }
      let(:bits_client) { double(BitsClient) }

      subject(:job) do
        ExternalPacker.new(app_guid, uploaded_path, fingerprints)
      end

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:bits_client).
          and_return(bits_client)
        allow(bits_client).to receive(:upload_entries).
          and_return(double(:response, code: 201, body: receipt.to_json))
        allow(bits_client).to receive(:bundles).
          and_return(double(:response, code: 200, body: 'contents'))
        allow(bits_client).to receive(:upload_package).
          and_return(package_guid)
        allow(Tempfile).to receive(:new).and_return(package_file)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'uses the bits_client to upload the zip file' do
          expect(bits_client).to receive(:upload_entries).with(uploaded_path)
          job.perform
        end

        it 'merges the bits-service receipt with the cli resources to ask for the bundles' do
          merged_fingerprints = fingerprints + receipt
          expect(bits_client).to receive(:bundles).
            with(merged_fingerprints.to_json)
          job.perform
        end

        it 'uploads the package to the bits service' do
          expect(bits_client).to receive(:upload_package) do |package_path|
            expect(File.read(package_path)).to eq('contents')
          end.and_return(double(Net::HTTPCreated, body: { guid: package_guid }.to_json))
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:external_packer)
        end

        it 'logs an error if the app cannot be found' do
          app.destroy

          logger = double(:logger, error: nil, info: nil)
          allow(job).to receive(:logger).and_return(logger)

          job.perform

          expect(logger).to have_received(:error).with("App not found: #{app_guid}")
        end

        it 'sets the package hash in the app' do
          job.perform
          expect(app.reload.package_hash).to eq(package_guid)
        end

        shared_examples 'a packaging failure' do
          let(:expected_exception) { Errors::ApiError }

          before do
            allow(App).to receive(:find).and_return(app)
          end

          it 'marks the app as failed to stage' do
            expect(app).to receive(:mark_as_failed_to_stage)
            job.perform rescue expected_exception
          end

          it 'raises the exception' do
            expect {
              job.perform
            }.to raise_error(expected_exception)
          end
        end

        context 'when no new bits are being uploaded' do
          let(:uploaded_path) { nil }

          it 'does not upload new entries to the bits service' do
            expect(bits_client).to_not receive(:upload_entries)
            job.perform
          end

          it 'downloads a bundle with the original fingerprints' do
            expect(bits_client).to receive(:bundles).with(fingerprints.to_json)
            job.perform
          end

          it 'uploads the package to the bits service' do
            expect(bits_client).to receive(:upload_package) do |package_path|
              expect(File.read(package_path)).to eq('contents')
            end
            job.perform
          end

          it 'sets the package hash in the app' do
            job.perform
            expect(app.reload.package_hash).to eq(package_guid)
          end
        end

        context 'when `upload_entries` fails' do
          before do
            allow(bits_client).to receive(:upload_entries).
              and_raise(BitsClient::Errors::UnexpectedResponseCode)
          end

          it_behaves_like 'a packaging failure'
        end

        context 'when `bundles` fails' do
          before do
            allow(bits_client).to receive(:bundles).
              and_raise(BitsClient::Errors::UnexpectedResponseCode)
          end

          it_behaves_like 'a packaging failure'
        end

        context 'when writing the package to a temp file fails' do
          let(:expected_exception) { StandardError.new('some error') }

          before do
            allow(Tempfile).to receive(:new).
              and_raise(expected_exception)
          end

          it_behaves_like 'a packaging failure'
        end

        context 'when uploading the package to the bits service fails' do
          let(:expected_exception) { StandardError.new('some error') }

          before do
            allow(bits_client).to receive(:upload_package).and_raise(expected_exception)
          end

          it_behaves_like 'a packaging failure'
        end

        context 'when the bits service has an internal error on upload_entries' do
          before do
            allow(bits_client).to receive(:upload_entries).
              and_raise(BitsClient::Errors::UnexpectedResponseCode)
          end

          it_behaves_like 'a packaging failure'
        end

        context 'when the bits service has an internal error on bundles' do
          before do
            allow(bits_client).to receive(:bundles).
              and_raise(BitsClient::Errors::UnexpectedResponseCode)
          end

          it_behaves_like 'a packaging failure'
        end
      end
    end
  end
end
