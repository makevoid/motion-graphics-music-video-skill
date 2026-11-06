require "json"
require "open3"
require "rbconfig"
require "securerandom"
require "thread"
require_relative "../workflow/approval"

module Toolkit
  # Only the Fal-facing recipes need the configured secret. Local setup, file
  # editing, and recording the user's approval stay in the ordinary Ruby CLI.
  class CredentialTasks
    TASKS = %w[doctor audio:transcribe media:stems media:upload sfx:gen
      pipeline:all adopt gen:ref_base gen:ref_torn gen:keyframes gen:video
      gen:shots gen:clips gen:music gen:overlay review:music].freeze
    OPTIONS = %w[RUN ONLY FORCE RECUT NEW_REQUEST VIDEO_RES SFX VFX REFRESH_UPLOAD].freeze
    OUTPUT_LIMIT = 20_000
    MAX_RUNNING = 10
    PLUGIN_KEY = "FAL_AI_API_KEY_PLUGIN"

    # The plugin option arrives under its own name: when it is unset Claude Code
    # passes "", which must not hide a FAL_AI_API_KEY exported by the launcher.
    def self.env_key(env = ENV)
      plugin = env[PLUGIN_KEY].to_s
      usable?(plugin) ? plugin : env["FAL_AI_API_KEY"].to_s
    end

    def self.usable?(key) = !key.strip.empty? && !key.include?("${user_config.")

    def initialize(entry: File.expand_path("../../mv.rb", __dir__), api_key: self.class.env_key)
      @entry, @api_key = entry, api_key.to_s
      @jobs, @lock = {}, Mutex.new
    end

    def configured? = self.class.usable?(@api_key)

    def start(project:, task:, options: {})
      raise ArgumentError, "Configure the plugin's FAL_AI_API_KEY, or set it in the environment when launching mcp.rb" unless configured? || task == "doctor"
      raise ArgumentError, "project must be an absolute initialized video project path" unless project.is_a?(String) && project.start_with?("/") && File.file?(File.join(project, "config/project.json"))
      project = File.realpath(project)
      runtime = File.realpath(File.dirname(@entry))
      raise ArgumentError, "Use a video project outside the installed toolkit" if project == runtime || project.start_with?(runtime + "/")
      match = task.is_a?(String) && /\A([a-z_:]+)(?:\[[^\]\r\n\x00]*\])?\z/.match(task)
      raise ArgumentError, "Unsupported task; use a documented Fal task or doctor" unless match && TASKS.include?(match[1])
      raise ArgumentError, "options must contain only supported string task options" unless options.is_a?(Hash) && options.all? { |key, value| OPTIONS.include?(key) && value.is_a?(String) && !value.include?("\0") }
      Workflow::Approval.new(root: project).check! unless task == "doctor"
      @lock.synchronize do
        raise ArgumentError, "Ten jobs are already running; wait for a job to finish" if @jobs.values.count { |j| j[:state] == "running" } >= MAX_RUNNING
        @jobs.delete(@jobs.find { |_, j| j[:state] != "running" }&.first) while @jobs.size >= 100
        id = SecureRandom.hex(12)
        # No shell command string, user-supplied executable, or secret argument.
        environment = OPTIONS.to_h { |key| [key, nil] }.merge(options).merge("FAL_AI_API_KEY" => configured? ? @api_key : nil, PLUGIN_KEY => nil)
        # Desktop MCP launchers can inherit a C/US-ASCII locale. Project text
        # and worker logs use UTF-8 regardless of the launcher's locale.
        stdin, output, waiter = Open3.popen2e(environment, RbConfig.ruby, "-EUTF-8", @entry,
          "--project", project, task, chdir: project, pgroup: true)
        stdin.close
        output.set_encoding(Encoding::UTF_8)
        job = { state: "running", output: "", waiter: waiter, started: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @jobs[id] = job
        job[:reader] = Thread.new do
          begin
            output.each_line do |line|
              safe = redact(line.encode("UTF-8", invalid: :replace, undef: :replace))
              @lock.synchronize do
                combined = job[:output] + safe
                job[:output] = combined.length > OUTPUT_LIMIT ? combined[-OUTPUT_LIMIT..] : combined
              end
            end
          ensure
            output.close
            status = waiter.value
            @lock.synchronize do
              job[:exit_code] = status.exitstatus
              job[:state] = status.success? ? "completed" : "failed" if job[:state] == "running"
            end
          end
        end
        { job_id: id, state: "running", next: "Poll task_status with this job_id. Do not start the same paid task again while it is running." }
      end
    end

    def status(id)
      @lock.synchronize do
        job = @jobs.fetch(id) { raise ArgumentError, "Unknown job_id; after a server restart use the project's saved Fal receipts to resume" }
        { job_id: id, state: job[:state], exit_code: job[:exit_code], output: job[:output].dup }
      end
    end

    def cancel(id)
      @lock.synchronize do
        job = @jobs.fetch(id) { raise ArgumentError, "Unknown job_id" }
        if job[:state] == "running"
          stop(job)
          job[:state] = "cancelled"
        end
      end
      status(id).merge(note: "Stops local processing only. A submitted Fal request may still run and incur charges; its receipt remains in the project.")
    end

    def close
      @lock.synchronize { @jobs.each_value { |job| stop(job) if job[:state] == "running" } }
      @jobs.each_value { |job| job[:reader].join(2) }
    end

    def redact(text)
      @api_key.empty? ? text : text.gsub(@api_key, "[REDACTED]")
    end

    private

    def stop(job)
      Process.kill("TERM", -job[:waiter].pid) if job[:waiter].alive?
    rescue Errno::ESRCH
      # It completed between the status check and the signal.
    end
  end

  # Minimal MCP stdio transport; stdout contains JSON-RPC messages only.
  class McpServer
    PROTOCOLS = %w[2025-11-25 2025-06-18 2025-03-26 2024-11-05].freeze
    JOB_SCHEMA = { type: "object", properties: { job_id: { type: "string" } }, required: ["job_id"], additionalProperties: false }.freeze
    TOOLS = [
      { name: "credential_status", description: "Check whether the Fal API key is configured. Never returns its value.",
        inputSchema: { type: "object", properties: {}, additionalProperties: false }, annotations: { readOnlyHint: true, openWorldHint: false } },
      { name: "run_task", description: "Start a Fal-facing Ruby toolkit task in an initialized, trusted video project. May upload media and incur Fal charges. Recorded production approval covers necessary uploads and generation within budget across RUNs; do not ask again per scene. Project Ruby configuration is executable code. Returns immediately; poll task_status. Local setup and plan approval use the Ruby CLI.",
        inputSchema: { type: "object", properties: {
          project: { type: "string", description: "Absolute path of the initialized video project" },
          task: { type: "string", description: "One Rake task, e.g. gen:ref_base or audio:transcribe[audio/song.wav,audio/words.json]" },
          options: { type: "object", properties: CredentialTasks::OPTIONS.to_h { |name| [name, { type: "string" }] }, additionalProperties: false }
        }, required: %w[project task], additionalProperties: false }, annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: true } },
      { name: "task_status", description: "Read a job's state, exit code and recent redacted output. Poll until completed or failed before accepting its asset.",
        inputSchema: JOB_SCHEMA, annotations: { readOnlyHint: true, openWorldHint: false } },
      { name: "cancel_task", description: "Stop a local task process. Does not cancel an already submitted Fal request or its charges.",
        inputSchema: JOB_SCHEMA, annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false } }
    ].freeze

    def initialize(input: $stdin, output: $stdout, tasks: CredentialTasks.new)
      @input, @output, @tasks = input, output, tasks
      # MCP's newline-delimited JSON is UTF-8, independent of Ruby's defaults.
      @input.set_encoding(Encoding::UTF_8)
      @output.set_encoding(Encoding::UTF_8)
    end

    def run
      @input.each_line do |line|
        request = JSON.parse(line)
        unless request.is_a?(Hash) && request["jsonrpc"] == "2.0" && request["method"].is_a?(String)
          send_error(nil, -32600, "Invalid request")
          next
        end
        next unless request.key?("id") # Notifications never receive a response.
        id, params = request["id"], request["params"] || {}
        result = case request["method"]
        when "initialize"
          requested = params["protocolVersion"]
          { protocolVersion: PROTOCOLS.include?(requested) ? requested : PROTOCOLS.first,
            capabilities: { tools: {} }, serverInfo: { name: "music-video", version: "0.2.6" } }
        when "ping" then {}
        when "tools/list" then { tools: TOOLS }
        when "tools/call" then call_tool(params)
        else
          send_error(id, -32601, "Method not found")
          next
        end
        send_message(jsonrpc: "2.0", id: id, result: result)
      rescue JSON::ParserError
        send_error(nil, -32700, "Invalid JSON")
      rescue StandardError => e
        send_error(request.is_a?(Hash) ? request["id"] : nil, -32603, @tasks.redact(e.message))
      end
    ensure
      @tasks.close
    end

    private

    def call_tool(params)
      args = params.fetch("arguments", {})
      tool = TOOLS.find { |item| item[:name] == params["name"] }
      raise ArgumentError, "Unknown tool" unless tool
      schema = tool[:inputSchema]
      raise ArgumentError, "Invalid tool arguments" unless args.is_a?(Hash) && (args.keys - schema[:properties].keys.map(&:to_s)).empty? && Array(schema[:required]).all? { |key| args.key?(key) }
      value = case params["name"]
      when "credential_status" then { configured: @tasks.configured? }
      when "run_task" then @tasks.start(project: args.fetch("project"), task: args.fetch("task"), options: args.fetch("options", {}))
      when "task_status" then @tasks.status(args.fetch("job_id"))
      when "cancel_task" then @tasks.cancel(args.fetch("job_id"))
      end
      { content: [{ type: "text", text: JSON.generate(value) }] }
    rescue StandardError => e
      { isError: true, content: [{ type: "text", text: @tasks.redact(e.message) }] }
    end

    def send_error(id, code, message) = send_message(jsonrpc: "2.0", id: id, error: { code: code, message: message })
    def send_message(message)
      @output.puts(JSON.generate(message))
      @output.flush
    end
  end
end
