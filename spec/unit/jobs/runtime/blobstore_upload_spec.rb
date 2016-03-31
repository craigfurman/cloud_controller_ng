require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreUpload do
      let(:local_file) { Tempfile.new('tmpfile') }
      let(:blobstore_key) { 'key' }
      let(:blobstore_name) { :droplet_blobstore }
      let(:worker) { Delayed::Worker.new }
      let(:blobstore_upload_job) do
        BlobstoreUpload.class_eval do
          def reschedule_at(_, _=nil)
            # induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
            Time.now.utc
          end
        end
        job
      end

      subject(:job) do
        BlobstoreUpload.new(local_file.path, blobstore_key, blobstore_name)
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'uploads the file to the blostore' do
          expect {
            job.perform
          }.to change {
            blobstore.exists?(blobstore_key)
          }.to(true)
        end

        it 'cleans up the file at the end' do
          job.perform
          expect(File.exist?(local_file.path)).to be false
        end
      end

      describe '#error' do
        before do
          Delayed::Worker.destroy_failed_jobs = false
          Delayed::Job.enqueue(blobstore_upload_job, queue: worker.name)
        end

        context 'copying to the blobstore fails' do
          before do
            allow(blobstore).to receive(:cp_to_blobstore) { raise 'UPLOAD FAILED' }
            worker.work_off 1
          end

          context 'retrying' do
            it 'does not delete the file' do
              expect(File.exist?(local_file.path)).to be true
            end
          end

          context 'when its the final attempt' do
            it 'it deletes the file' do
              worker.work_off 1

              expect {
                worker.work_off 1
              }.to change {
                File.exist?(local_file.path)
              }.from(true).to(false)
            end
          end
        end

        context 'if the file is missing' do
          before do
            FileUtils.rm_f(local_file)
            allow(blobstore).to receive(:cp_to_blobstore) { raise 'File not found' }
            worker.work_off 1
          end

          it 'receives an error' do
            expect(Delayed::Job.last.last_error).to match(/File not found/)
          end

          it 'does not retry' do
            worker.work_off 1
            expect(Delayed::Job.last.attempts).to eq 1
          end
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:blobstore_upload)
      end

      context 'when using bits service with buildpack_cache resource' do
        let(:bits_client) { double(:bits_client) }
        let(:blobstore_name) { :buildpack_cache_blobstore }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:bits_client).and_return(bits_client)
          allow(bits_client).to receive(:upload_buildpack_cache)
        end

        describe '#perform' do
          it 'calls the bits client with the correct arguments' do
            expect(bits_client).to receive(:upload_buildpack_cache).with(blobstore_key, local_file.path)
            job.perform
          end

          it 'cleans up the file at the end' do
            expect {
              job.perform
            }.to change {
              File.exist?(local_file.path)
            }.from(true).to(false)
          end
        end

        describe '#error' do
          context 'uploading to bits service fails' do
            before do
              allow(bits_client).to receive(:upload_buildpack_cache).and_raise(StandardError.new('failed here'))
              Delayed::Worker.destroy_failed_jobs = false
              Delayed::Job.enqueue(blobstore_upload_job, queue: worker.name)
              worker.work_off 1
            end

            it 'receives an error' do
              expect(Delayed::Job.last.last_error).to match(/failed here/)
            end

            it 'does not delete the file' do
              expect(File.exist?(local_file.path)).to be true
            end

            context 'when its the final attempt' do
              it 'it deletes the file' do
                worker.work_off 1

                expect {
                  worker.work_off 1
                }.to change {
                  File.exist?(local_file.path)
                }.from(true).to(false)
              end
            end
          end
        end
      end
    end
  end
end
