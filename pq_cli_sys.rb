# frozen_string_literal: true

# Contains constants and methods dealing with capturing from the tmux session
# and writing it to file.
module PqCliSys
  SOCKET = "#{Dir.home}/.tmux_pqcli_socket".freeze
  TMUX_PREFIX_CMDS = ['tmux', '-S', SOCKET].freeze

  CAPTURE_FILENAME_OUT_TEXT = {
    true =>
      ['.capture', 'Capture success! pqcli running, capture saved to ' \
                   '.capture and .capture.old'],
    false =>
      ['.capture.old', 'Capture failed (pqcli may not be running). Using ' \
                       'previous .capture.old']
  }.freeze

  module_function

  def capture_and_write_to_file_sys
    # Set window size to 150x10,000 for max information
    resized_for_capture = system(*TMUX_PREFIX_CMDS, 'resize-window', '-t',
                                 'pqcli', '-x', '150', '-y', '10000')

    # Capture pane with the spoofed size
    captured = system(*TMUX_PREFIX_CMDS, 'capture-pane', '-t', 'pqcli', '-pJ',
                      out: '.capture')

    # Reset the size so that `tmux a` to the session resizes to fit the terminal
    resized_back_to_auto = system(*TMUX_PREFIX_CMDS, 'set-option', '-t',
                                  'pqcli', 'window-size', 'largest')

    resized_for_capture and captured and resized_back_to_auto
  end

  def capture_and_write_to_file
    success = capture_and_write_to_file_sys
    system('cp', '.capture', '.capture.old') if success

    filename, out_text = CAPTURE_FILENAME_OUT_TEXT[success]
    puts out_text

    [filename, success]
  end
end
