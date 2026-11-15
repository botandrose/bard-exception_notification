# frozen_string_literal: true

RSpec.describe "delayed_job" do
  FakeDelayedJob = Struct.new(:attempts, :max_attempts, :error, :run_at, keyword_init: true) do
    def name = "FakeDelayedJob"
    def id = 42
    def queue = "default"
    def reschedule_at = Time.now
    def unlock; end
    def save!; end
    def hook(_name); end
    def destroy_failed_jobs? = false
    def fail!; end
  end

  def fail_attempt(job)
    Delayed::Worker.new(quiet: true).send(:handle_failed_job, job, RuntimeError.new("delayed boom"))
  end

  it "emails once delayed_job gives up on a job" do
    job = FakeDelayedJob.new(attempts: 2, max_attempts: 3)

    fail_attempt(job)

    expect(deliveries.size).to eq 1
    expect(deliveries.first.body.to_s).to include "delayed boom", "FakeDelayedJob"
  end

  it "sends nothing while delayed_job will still retry" do
    fail_attempt(FakeDelayedJob.new(attempts: 0, max_attempts: 3))
    fail_attempt(FakeDelayedJob.new(attempts: 1, max_attempts: 3))

    expect(deliveries).to be_empty
  end

  it "emails a job with a single attempt" do
    fail_attempt(FakeDelayedJob.new(attempts: 0, max_attempts: 1))

    expect(deliveries.size).to eq 1
  end

  it "leaves ActiveJob jobs running on delayed_job to the delayed_job hook" do
    job_class = Class.new(ApplicationJob) do
      def self.name = "DelayedFailingJob"
      def perform = raise("retried by delayed_job")
    end
    job_class.queue_adapter = :delayed_job

    expect { job_class.perform_now }.to raise_error("retried by delayed_job")

    expect(deliveries).to be_empty
  end

  describe "the test job" do
    it "gives up after one attempt" do
      job = Bard::ExceptionNotification::TestDelayedJob.new("delayed test")

      expect { job.perform }.to raise_error(Bard::ExceptionNotification::TestError, "delayed test")
      expect(job.max_attempts).to eq 1
    end

    it "survives delayed_job's YAML round trip" do
      job = YAML.load_dj(Bard::ExceptionNotification::TestDelayedJob.new("delayed test").to_yaml)

      expect { job.perform }.to raise_error(Bard::ExceptionNotification::TestError, "delayed test")
    end

    it "is enqueued by the job check" do
      delayed_job = class_double("Delayed::Job").as_stubbed_const
      allow(delayed_job).to receive(:enqueue)

      expect { Bard::ExceptionNotification::Test.job }.to output(/job: enqueued .*\ndelayed_job: enqueued Bard::ExceptionNotification::TestDelayedJob/).to_stdout
      expect(delayed_job).to have_received(:enqueue).with(an_instance_of(Bard::ExceptionNotification::TestDelayedJob))
    end

    it "replaces the ActiveJob check when ActiveJob runs on delayed_job" do
      allow(Bard::ExceptionNotification::TestJob).to receive(:queue_adapter).and_return(ActiveJob::QueueAdapters::DelayedJobAdapter.new)
      delayed_job = class_double("Delayed::Job").as_stubbed_const
      allow(delayed_job).to receive(:enqueue)

      expect { Bard::ExceptionNotification::Test.job }.to output(/\Ajob: ActiveJob runs on delayed_job here/).to_stdout
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
    end
  end
end
