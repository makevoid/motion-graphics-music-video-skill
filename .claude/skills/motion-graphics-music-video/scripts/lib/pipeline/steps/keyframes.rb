module Pipeline
  module Steps
    # Step 2b — new framings of the reference character (extreme close-up, reframed, other gaze...) for the Shots step:
    # prompts/<run>/02_keyframes.yml { name => edit prompt }, each sent with the ref_base image to gpt-image-2.6/edit.
    # A spec can also be { "prompt" => ..., "refs" => [run, ...] } to add other runs' ref_base images (a second character):
    # image_urls = [this run's ref_base, *those], so the prompt can say "the character in the second image".
    # "base" => <keyframe name> edits an earlier keyframe of this list instead of ref_base (same framing, new pose),
    # "base" => false sends only the refs (a keyframe without the singer), "base" => "<run>/<keyframe>" edits another run's keyframe.
    class Keyframes < ItemsStep
      MODEL = Fal::Models::GptImage26Edit

      def specs = yaml("02_keyframes")

      def generate(name, spec)
        spec = { "prompt" => spec } if spec.is_a?(String)
        refs = Array(spec["refs"]).map { |run| Project.new(run).fetch!(:ref_base, :url) }
        result = MODEL.new(client: client).edit(prompt: spec.fetch("prompt"), image_urls: [*base_url(spec.fetch("base", "ref_base")), *refs])
        url = result.output.fetch("images").first["url"]
        { request_id: result.request_id, input: result.input, url: url, path: download(url, "02_kf_#{name}.png") }
      end

      # Deliverable: a labelled board of the reference + every keyframe.
      def finish(items)
        pairs = [[project[:ref_base]["path"], "ref_base"]] + items.map { |name, item| [item["path"], name] }
        { path: magick.board(pairs, project.path("02_keyframes.jpg"), tile: "2x", width: 960) }
      end

      def review
        items = project[key]["items"]
        info = items.transform_values { |item| magick.identify(item["path"]) }
        {
          board: project[key]["path"], images: info,
          **verdict(items.keys.to_h { |name| ["#{name} 16:9 >= 1920w", [(info[name][:aspect] - 1.778).abs < 0.05 && info[name][:w] >= 1920, "#{info[name][:w]}x#{info[name][:h]}"]] })
        }
      end

      protected

      def endpoint = MODEL.endpoint

      private

      def base_url(base)
        return if base == false
        return project.fetch!(:ref_base, :url) if base == "ref_base"
        return project.keyframe(base)["url"] if base.include?("/")
        project.fetch!(key, :items).fetch(base) { raise "[#{key}] base '#{base}' must be a keyframe listed before this one" }["url"]
      end
    end
  end
end
