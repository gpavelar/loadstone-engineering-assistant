require "open3"
require "json"
require "timeout"

class ClaudeCodeRunner
  DEFAULT_TIMEOUT = 1800
  KILL_GRACE_SECONDS = 2

  class Result
    def initialize(text: nil, error: nil, raw_stdout: nil)
      @text = text
      @error = error
      @raw_stdout = raw_stdout
    end
    attr_reader :text, :error, :raw_stdout
    def to_h = { text: @text, error: @error, raw_stdout: @raw_stdout }
    def [](k) = to_h[k]
  end

  def initialize(cli: ENV.fetch("CLAUDE_CLI", "claude"),
                 workdir: ENV.fetch("CLAUDE_WORKDIR", Dir.pwd),
                 timeout: ENV.fetch("INVESTIGATION_TIMEOUT_SECONDS", DEFAULT_TIMEOUT).to_i)
    @cli = cli
    @workdir = workdir
    @timeout = timeout
  end

  # prompt: String — the user-facing prompt (idea title + body + steering)
  # system_prompt: String — appended to Claude Code's default system prompt
  def run(prompt:, system_prompt:)
    stdout, stderr, status = spawn_claude(prompt, system_prompt)
    parse(stdout, stderr, status).to_h
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOEXEC => e
    Result.new(error: "Claude CLI not runnable (#{e.class}: #{e.message}). Set CLAUDE_CLI env var or check the binary.").to_h
  rescue Timeout::Error
    Result.new(error: "Investigation exceeded #{@timeout}s timeout").to_h
  end

  private

  # Drains stdout and stderr in separate threads (avoids the popen3 deadlock
  # where a child blocks on a full stderr pipe while the parent is blocked
  # reading stdout). Enforces the timeout via wait_thr.join(timeout) and
  # explicitly TERM/KILLs the child if it does not finish in time.
  def spawn_claude(prompt, system_prompt)
    Rails.logger.info "[ClaudeCodeRunner] spawning #{@cli} in #{@workdir} (timeout=#{@timeout}s)"

    Open3.popen3(
      @cli,
      "-p",
      "--output-format", "json",
      "--append-system-prompt", system_prompt,
      chdir: @workdir
    ) do |stdin, stdout, stderr, wait_thr|
      stdin.write(prompt)
      stdin.close

      out_thread = Thread.new { stdout.read }
      err_thread = Thread.new { stderr.read }

      finished = wait_thr.join(@timeout)
      if finished.nil?
        terminate_subprocess(wait_thr.pid)
        out_thread.kill
        err_thread.kill
        raise Timeout::Error, "claude exceeded #{@timeout}s"
      end

      [ out_thread.value, err_thread.value, wait_thr.value ]
    end
  end

  def terminate_subprocess(pid)
    Process.kill("TERM", pid)
    sleep KILL_GRACE_SECONDS
    Process.kill("KILL", pid)
  rescue Errno::ESRCH
    # process already exited — fine
  end

  def parse(stdout, stderr, status)
    unless status&.success?
      Rails.logger.error "[ClaudeCodeRunner] stderr: #{stderr}" if stderr.present?
      msg = stderr.presence || "exited with code #{status&.exitstatus}"
      return Result.new(error: msg.to_s[0, 500], raw_stdout: stdout)
    end

    data = JSON.parse(stdout)
    text = data["result"] || data["text"]
    return Result.new(error: "Claude response missing result key", raw_stdout: stdout) if text.blank?

    Result.new(text: text, raw_stdout: stdout)
  rescue JSON::ParserError
    Result.new(error: "Claude returned non-JSON output", raw_stdout: stdout)
  end
end
