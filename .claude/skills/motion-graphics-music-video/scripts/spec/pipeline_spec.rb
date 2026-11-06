require_relative "spec_helper"
# Uses the real Client#run receipt/approval path, with deterministic synthetic provider I/O.
class SyntheticFal < Fal::Client
  attr_reader :calls
  def initialize(image:, video:)
    super(api_key: "fixture-only", poll_interval: 0)
    @image, @video, @calls, @results = image, video, [], {}
  end
  def submit(endpoint, input)
    id = "fixture-#{@calls.size}"
    @calls << [endpoint, input]
    @results[id] = endpoint.include?("image-to-video") ? {"video" => {"url" => "fixture://video"}} : {"images" => [{"url" => "fixture://image"}]}
    {"request_id" => id, "status_url" => id, "response_url" => id}
  end
  def wait(*) = true
  def get_json(id) = @results.fetch(id)
  def upload(path, **) = "fixture://#{File.basename(path)}"
  def download(url, path)
    FileUtils.cp(url == "fixture://video" ? @video : @image, path)
    path
  end
end
RSpec.describe "Character to animated scene pipeline", :media do
  it "creates an edited character identity version without overwriting the original" do
    image = character
    before = Digest::SHA256.file(image).hexdigest
    original = Pipeline::Project.new("e2e-original-#{Process.pid}")
    revised = Pipeline::Project.new("e2e-revised-#{Process.pid}")
    original.record(:ref_base, path: image, url: "fixture://approved-v1")
    stub_const("Pipeline::GENERATIONS", {revised.name => {steps:[Pipeline::Steps::RefBase], edit_from: original.name}})
    dir=File.join(RT,"prompts",revised.name); FileUtils.mkdir_p(dir)
    File.write(File.join(dir,"01_ref_base.txt"),"Keep the same character; change the hairstyle to approved v2")
    client = SyntheticFal.new(image:image,video:image)
    with_workspace do
      approve
      Pipeline::Steps::RefBase.new(project:revised,client:client).run!
    end
    expect(client.calls.first[0]).to eq(Fal::Models::GptImage26Edit.endpoint)
    expect(client.calls.first[1][:image_urls]).to eq(["fixture://approved-v1"])
    expect(Digest::SHA256.file(image).hexdigest).to eq(before)
    expect(revised[:ref_base]["path"]).not_to eq(image)
  end
  it "generates identity, edits a pose, supplies H3 vocals, cuts alpha and assembles placed animation" do
    image = character(file("identity.png"), width: 1920, height: 1080)
    song = tone(duration: 5)
    movie = video(file("animation.mp4"), audio: song, seconds: 5)
    run = "e2e-character-#{Process.pid}"
    generation = {steps: [Pipeline::Steps::RefBase, Pipeline::Steps::Keyframes, Pipeline::Steps::Clips], **Pipeline.section(0, 24)}
    stub_const("Pipeline::GENERATIONS", {run => generation})
    project = Pipeline::Project.new(run)
    prompt_dir = File.join(RT, "prompts", run); FileUtils.mkdir_p(prompt_dir)
    File.write(File.join(prompt_dir, "01_ref_base.txt"), "Expressive red robot character sheet; fixture")
    File.write(File.join(prompt_dir, "02_keyframes.yml"), YAML.dump({"pose" => {"prompt" => "Same robot, raise hand"}, "later" => {"prompt" => "Same robot, grin"}}))
    File.write(File.join(prompt_dir, "04_clips.yml"), YAML.dump([{"name" => "sing", "image" => "pose", "seconds" => 5, "key" => "green", "audio" => song, "audio_at" => 0, "frames" => 24, "prompt" => "Animate the same robot with clear singing mouth movements"}]))
    client = SyntheticFal.new(image: image, video: movie)
    with_workspace do
      approve
      base = Pipeline::Steps::RefBase.new(project: project, client: client)
      base.run!
      expect(base.review![:verdict]).to eq("PASS")
      base.run! # A completed asset skips another model call.
      expect(client.calls.size).to eq(1)
      ENV["ONLY"] = "pose"
      Pipeline::Steps::Keyframes.new(project: project, client: client).run!
      expect(project[:keyframes]["items"].keys).to eq(["pose"])
      ENV.delete("ONLY")
      Pipeline::Steps::Keyframes.new(project: project, client: client).run!
      Pipeline::Steps::Clips.new(project: project, client: client).run!
    end
    expect(client.calls[0][0]).to eq("openai/gpt-image-2.6/sunburst/text-to-image")
    expect(client.calls[0][1]).to include(quality: "high", reasoning_effort: "high")
    expect(client.calls[1][1]).to include(quality: "high", reasoning_effort: "high")
    expect(client.calls[1][0]).to eq(Fal::Models::GptImage26Edit.endpoint)
    h3 = client.calls.last
    expect(h3[1]).to include(resolution: "1080P", duration: 5)
    expect(h3[1][:target_audio_url]).to start_with("fixture://04_audio_")
    meta = JSON.parse(File.read(project[:clips]["items"]["sing"]["path"]))
    expect(meta["frames"]).to eq(24)
    json(file("clips.json"), sing: meta)
    File.write(file("scene.js"), "Anim.sketch({async load(){this.s=await Anim.clip('sing')},draw(t,f){this.s.draw(this.s.at(t),240,90,180); noStroke();fill('#ffffff');rect(10+f,10,8,8)}})")
    Media::Anim.new.render(file("scene.js"), file("rendered"), width: 320, height: 180, fps: 24, frames: 24, data: {clips: file("clips.json")})
    base = ff.still_plate(image, song, file("plate.mp4"), seconds: 1, w: 320, h: 180)
    ff.overlay_frames(base, file("rendered"), file("final.mp4"), fps: 24)
    expect(ff.summary(file("final.mp4")).dig(:video, :frames)).to eq(24)
    px = pixels(file("rendered/0000.png"))
    expect(px[90 * 320 + 240][3]).to be > 250
    expect(px[90 * 320 + 20][3]).to eq(0)
  end
  it "rejects singing retimes before any model call" do
    project = instance_double(Pipeline::Project)
    step = Pipeline::Steps::Shots.new(project: project, client: double("unused"))
    expect { step.generate("sing", {"audio" => true, "retime" => true}) }.to raise_error(ArgumentError, /Never retime/)
  end
  it "runs the mouth alignment diagnostic against synthetic mouth and vocal activity" do
    song = tone(duration: 2)
    dir = file("mouth"); FileUtils.mkdir_p(dir)
    48.times do |i|
      # Vary mouth darkness with a known pattern; the final silent frames close fully.
      h = i < 36 ? (5 + i % 12) : 0
      magick.run("magick", "-size", "40x30", "xc:white", "-fill", "black", "-draw", "rectangle 10,10 30,#{10+h}", File.join(dir, format("%04d.png", i)), quiet: true)
    end
    raw = py.run(py.executable, File.join(Media::Python::SCRIPTS, "mouth_sync.py"), dir, song, "0", "5", "5", "30", "20", "--pauses", "1.5-2", quiet: true)
    data = JSON.parse(raw.lines.last)
    expect(data["best_lag"]).to be_between(-6,6)
    expect(data["pauses"].first["mean"]).to be < data["mouth_voiced"]
  end
end
