require_relative "spec_helper"
RSpec.describe "Skill contracts and Ruby entry", :core do
  it "loads valid metadata and resolves every bundled Markdown reference" do
    skill = File.read(File.join(SKILL, "SKILL.md"))
    front = YAML.safe_load(skill.split("---", 3)[1])
    expect(front.fetch("name")).to eq("motion-graphics-music-video")
    expect(front.fetch("description").length).to be > 30
    Dir[File.join(SKILL, "**", "*.md")].reject { |p| p.include?("node_modules") || p.include?("/tmp/") }.each do |path|
      File.read(path).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |target|
        next if target.start_with?("https:", "http:", "#")
        expect(File.exist?(File.expand_path(target.split("#").first, File.dirname(path)))).to be(true), "Broken reference #{target} in #{path}"
      end
    end
  end
  it "shows help without credentials and lists executable tasks" do
    out, err, status = cli("--help", env: {"FAL_AI_API_KEY" => ""})
    expect(status.exitstatus).to eq(0), err
    expect(out).to include("--project", "Exit:")
    out, err, status = cli("-T")
    expect(status.exitstatus).to eq(0), err
    expect(out).to include("gen:ref_base", "media:mouth", "vfx:render", "test")
  end
  it "rejects incomplete intake without prompting or overwriting an existing project" do
    _, _, status = cli("init")
    expect(status.exitstatus).to eq(2)
    File.write(file("song.wav"), "fixture"); File.write(file("brief.md"), "Dancing robot")
    dir = file("project")
    out, err, status = cli("init", "--project", dir, "--song", file("song.wav"), "--prompt-file", file("brief.md"))
    expect(status.exitstatus).to eq(0), err
    expect(JSON.parse(out)["project"]).to eq(dir)
    expect(File.read(File.join(dir, "docs/BRIEF.md"))).to eq("Dancing robot")
    _, _, status = cli("init", "--project", dir, "--song", file("song.wav"), "--prompt-file", file("brief.md"))
    expect(status.exitstatus).to eq(2)
  end
  it "executes shell arguments literally, including spaces and shell metacharacters" do
    dangerous = "a path; $(touch SHOULD_NOT_EXIST) `x`"
    out = Media::Shell.new.run(RbConfig.ruby, "-e", "print ARGV.fetch(0)", dangerous, quiet: true)
    expect(out).to eq(dangerous)
    expect(File.exist?("SHOULD_NOT_EXIST")).to be(false)
  end
  it "surfaces a backend failure" do
    expect { Media::Shell.new.run(RbConfig.ruby, "-e", "STDERR.puts 'fixture failure'; exit 9", quiet: true) }.to raise_error(Media::CommandError, /fixture failure/)
  end
  it "invalidates approval when the creative plan changes" do
    with_workspace do
      expect { Workflow::Approval.new.check! }.to raise_error(/approval missing/)
      approve
      expect(Workflow::Approval.new.check!).to be(true)
      File.write("docs/PLAN.md", "Different cast and story")
      expect { Workflow::Approval.new.check! }.to raise_error(/Plan changed/)
    end
  end
  it "reads and records UTF-8 approval files independently of the locale" do
    with_workspace do
      approve
      File.write("docs/PLAN.md", "Bloom — 音楽", encoding: "UTF-8")
      note = "Approve wave 2 — café / 音楽"
      Workflow::Approval.new.record!(note)
      script = <<~RUBY
        # encoding: UTF-8
        require #{File.join(RT, "lib/workflow/approval").inspect}
        abort "Expected US-ASCII" unless Encoding.default_external == Encoding::US_ASCII
        approval = Workflow::Approval.new
        approval.check!
        approval.record!(#{note.inspect})
        approval.check!
      RUBY
      _, err, status = Open3.capture3({"LC_ALL" => "C", "LANG" => "C"}, RbConfig.ruby, "-EUS-ASCII", "-e", script)
      expect(status.success?).to be(true), err
      expect(JSON.parse(File.read("config/approval.json", encoding: "UTF-8"))["user_approval"]).to eq(note)
    end
  end
  it "allocates reviewed dependency waves 2,4,8,10,10 and resumes an active wave" do
    with_workspace do
      FileUtils.mkdir_p("config")
      jobs = 34.times.map { |i| {id: "j#{i}", run: "r#{i}", state: "pending", depends: []} }
      json("config/production.json", wave: 0, jobs: jobs)
      waves = Workflow::Waves.new
      File.write("review.md", "Reviewed fixture output")
      [2, 4, 8, 10, 10].each do |count|
        result = waves.next!
        expect(result[:jobs].size).to eq(count)
        expect(waves.next![:jobs]).to eq(result[:jobs])
        result[:jobs].each { |j| waves.accept!(j["id"], "review.md") }
      end
      expect(waves.next![:complete]).to be(true)
    end
  end
  it "waits for dependencies, prevents shared run ownership and detects cycles" do
    with_workspace do
      FileUtils.mkdir_p("config")
      json("config/production.json", jobs: [{id: "a", run: "shared"}, {id: "b", run: "shared"}, {id: "c", depends: ["a"]}])
      result = Workflow::Waves.new.next!
      expect(result[:jobs].map { |j| j["id"] }).to eq(["a"])
      json("config/production.json", jobs: [{id: "a", depends: ["b"]}, {id: "b", depends: ["a"]}])
      expect { Workflow::Waves.new.next! }.to raise_error(/No jobs ready/)
    end
  end
  it "refuses noncontiguous section assembly before touching media" do
    stub_const("Pipeline::GENERATIONS", {
      "test-a" => {steps: [], **Pipeline.section(0, 24)},
      "test-b" => {steps: [], **Pipeline.section(25, 24)}
    })
    expect { Toolkit::Operations.new.preview(file("out.mp4"), %w[test-a test-b]) }.to raise_error(/Noncontiguous/)
  end
end

RSpec.describe "Fal HTTP and model contracts", :core do
  it "caches CDN upload URLs by bytes and downloads real response bytes" do
    with_workspace do
      File.write("image.png", "test image bytes")
      Excon.defaults[:mock] = true
      calls = 0
      Excon.stub({method: :post, host: "rest.alpha.fal.ai"}) do
        calls += 1
        {status:200, body: JSON.generate(upload_url:"https://upload.test/file",file_url:"https://cdn.test/file")}
      end
      Excon.stub({method: :put, host:"upload.test"},{status:200,body:""})
      Excon.stub({method: :get, host:"cdn.test"},{status:200,body:"downloaded bytes"})
      client = Fal::Client.new(api_key:"fixture")
      expect(client.upload("image.png")).to eq("https://cdn.test/file")
      expect(client.upload("image.png")).to eq("https://cdn.test/file")
      expect(calls).to eq(1)
      client.download("https://cdn.test/file","download.png")
      expect(File.read("download.png")).to eq("downloaded bytes")
    end
  end
  it "keeps the receipt after a polling interruption and recovers without another POST" do
    with_workspace do
      approve
      client = Fal::Client.new(api_key:"fixture")
      expect(client).to receive(:submit).once.and_return({"request_id"=>"resume-1","status_url"=>"status","response_url"=>"result"})
      allow(client).to receive(:wait).and_raise(Fal::Error,"timeout")
      expect { client.run("test/endpoint",{prompt:"once"}) }.to raise_error(Fal::Error,/timeout/)
      allow(client).to receive(:wait).and_return(true)
      allow(client).to receive(:get_json).with("result").and_return({"ok"=>true})
      expect(client.run("test/endpoint",{prompt:"once"})).to eq(["resume-1",{"ok"=>true}])
    end
  end
  it "submits, polls, fetches and resumes identical paid requests without resubmitting" do
    with_workspace do
      approve
      Excon.defaults[:mock] = true
      submitted = []
      Excon.stub({method: :post, host: "queue.fal.run"}) do |req|
        submitted << JSON.parse(req[:body])
        {status: 200, body: JSON.generate(request_id: "job-1", status_url: "https://queue.fal.run/status", response_url: "https://queue.fal.run/result")}
      end
      Excon.stub({method: :get, path: "/status"}, {status: 200, body: '{"status":"COMPLETED"}'})
      Excon.stub({method: :get, path: "/result"}, {status: 200, body: '{"images":[{"url":"https://cdn.test/image.png"}]}'})
      client = Fal::Client.new(api_key: "test-only", poll_interval: 0)
      2.times { expect(Fal::Models::GptImage26.new(client: client).generate(prompt: "fixture").request_id).to eq("job-1") }
      expect(submitted.size).to eq(1)
      expect(submitted.first).to include("quality" => "high", "reasoning_effort" => "high", "output_format" => "png")
      expect(Dir["output/requests/*.json"].size).to eq(1)
    end
  end
  it "validates endpoint inputs against a saved schema before submission" do
    with_workspace do
      path = Fal::OpenAPI.spec_path(Fal::Models::H3MaxImageToVideo.endpoint)
      json(path, components: {schemas: {Input: {required: ["prompt"], properties: {prompt: {type: "string"}, resolution: {enum: ["1080P"]}}}}})
      client = double("no network")
      expect(client).not_to receive(:run)
      expect { Fal::Models::H3MaxImageToVideo.new(client: client).animate(prompt: "x", image_url: "https://test/image", duration: 5, resolution: "bad") }.to raise_error(ArgumentError)
    end
  end
  it "surfaces terminal queue errors and never calls a paid endpoint before approval" do
    with_workspace do
      client = Fal::Client.new(api_key: "test-only", poll_interval: 0)
      expect(client).not_to receive(:submit)
      expect { client.run("test/model", {}) }.to raise_error(/approval missing/)
      allow(client).to receive(:get_json).and_return({"status" => "COMPLETED", "error" => "generation rejected"})
      expect { client.wait("https://test/status") }.to raise_error(Fal::Error, /generation rejected/)
    end
  end
end
