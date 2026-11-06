require_relative "spec_helper"

RSpec.describe "Sunburst 2.6 requests", :core do
  [
    [Fal::Models::GptImage26, :generate, "text-to-image", {}],
    [Fal::Models::GptImage26Edit, :edit, "edit", {image_urls: ["https://cdn.test/identity.png"]}]
  ].each do |model, method, route, references|
    it "sends #{route} to the 2.6 endpoint with high rendering and reasoning defaults" do
      with_workspace do
        approve
        Excon.defaults[:mock] = true
        submitted = []
        Excon.stub({method: :post, host: "queue.fal.run", path: "/openai/gpt-image-2.6/sunburst/#{route}"}) do |request|
          submitted << JSON.parse(request[:body])
          {status: 200, body: JSON.generate(request_id: "image-26", status_url: "https://queue.fal.run/status", response_url: "https://queue.fal.run/result")}
        end
        Excon.stub({method: :get, path: "/status"}, {status: 200, body: '{"status":"COMPLETED"}'})
        Excon.stub({method: :get, path: "/result"}, {status: 200, body: '{"images":[{"url":"https://cdn.test/output.png"}]}'})
        adapter = model.new(client: Fal::Client.new(api_key: "fixture", poll_interval: 0))
        result = adapter.public_send(method, prompt: "Professor character", **references)
        expect(result.output.fetch("images").first.fetch("url")).to eq("https://cdn.test/output.png")
        expect(submitted.fetch(0)).to include(
          "quality" => "high", "reasoning_effort" => "high", "output_format" => "png",
          "num_images" => 1, "image_size" => {"width" => 2752, "height" => 1536},
          **references.transform_keys(&:to_s)
        )
        # Explicit user choices must survive the defaults and use a distinct receipt.
        adapter.public_send(method, prompt: "Professor character", quality: "medium", reasoning_effort: "low",
                            image_size: {width: 1024, height: 1024}, **references)
        expect(submitted.size).to eq(2)
        expect(submitted.last).to include("quality" => "medium", "reasoning_effort" => "low",
                                          "image_size" => {"width" => 1024, "height" => 1024})
      end
    end
  end
end
