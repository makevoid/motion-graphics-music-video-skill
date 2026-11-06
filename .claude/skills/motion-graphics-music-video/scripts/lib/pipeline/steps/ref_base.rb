module Pipeline
  module Steps
    # Step 1 — the singer reference frame (text-to-image, prompt = prompts/<run>/01_ref_base.*).
    # GPT Image 2.6 Sunburst unless the generation explicitly sets image_model:.
    class RefBase < Step
      MODEL = Fal::Models::GptImage26

      def submit
        if (source = project.generation[:edit_from])
          url = source.include?("/") ? project.keyframe(source).fetch("url") : Project.new(source).fetch!(:ref_base, :url)
          return model.new(client: client).edit(prompt: project.prompt("01_ref_base"), image_urls: [url])
        end
        model.new(client: client).generate(prompt: project.prompt("01_ref_base"), aspect_ratio: "16:9", seed: seed)
      end

      def materialize(result)
        image = result.output.fetch("images").first
        base_data(result).merge(url: image["url"], path: download(image["url"], "01_ref_base.png"),
                                description: result.output["description"])
      end

      def review
        path = project[key]["path"]
        info = magick.identify(path)
        split = python.style_split(path)["images"].first
        preview = magick.preview(path, project.review_path(key, "preview.jpg"))
        checks = {
          "16:9 landscape" => [(info[:aspect] - 1.778).abs < 0.05, "aspect #{info[:aspect]}"],
          "resolution >= 1920w" => [info[:w] >= 1920, "#{info[:w]}x#{info[:h]}"]
        }
        # Only a base that gets torn open (run1) must be full color; run2's muted watercolor is mostly low-saturation.
        if project.step?(RefTorn)
          checks["mostly colored"] = [split["mono_pct"] < 35, "mono #{split["mono_pct"]}% (the base layer should be full color)"]
        end
        { image: info, style: split, preview: preview, **verdict(checks) }
      end

      protected

      def model = project.generation[:edit_from] ? Fal::Models::GptImage26Edit : project.generation.fetch(:image_model, MODEL)
      def endpoint = model.endpoint
    end
  end
end
